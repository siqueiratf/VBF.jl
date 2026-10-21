#!/usr/bin/env python3
"""Summarize a bounded, read-only tail of an ordered closure packet log.

This inspects emitted packet telemetry only. It never opens the search database.
Ready-wait is completion-to-application delay, not necessarily idle CPU time.
Without timestamps, preceding slow computations are possible blockers rather
than proven head-of-line causes. A tail is also not a random sample of the run.
"""

import argparse
from collections import Counter, deque
from datetime import datetime, timezone
import hashlib
import io
import json
import math
import os
from pathlib import Path
import sys


MAX_BYTES = 64 * 1024 * 1024
MAX_RECORDS = 100_000
TIMESTAMP_KEYS = ("utc", "timestamp", "applied_utc", "finished_utc", "time")
METRIC_KEYS = (
    "compute_wall_seconds", "ready_wait_seconds", "application_wall_seconds"
)
IDENTITY_KEYS = (
    "parent_id", "job_id", "kind", "first_direction", "reservation_ticket",
    "compute_slot", "processed_cosets"
)


def number(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    value = float(value)
    return value if math.isfinite(value) and value >= 0 else None


def quantile(sorted_values, probability):
    if not sorted_values:
        return None
    position = (len(sorted_values) - 1) * probability
    left = int(position)
    right = min(left + 1, len(sorted_values) - 1)
    return sorted_values[left] + (position - left) * (
        sorted_values[right] - sorted_values[left]
    )


def statistics(values):
    values = sorted(value for value in values if value is not None)
    return {
        "count": len(values),
        "sum": math.fsum(values),
        "mean": math.fsum(values) / len(values) if values else None,
        "p50": quantile(values, .5),
        "p90": quantile(values, .9),
        "p95": quantile(values, .95),
        "p99": quantile(values, .99),
        "p999": quantile(values, .999),
        "max": values[-1] if values else None,
        "strictly_greater_than_seconds": {
            str(threshold): sum(value > threshold for value in values)
            for threshold in (1, 4, 10)
        },
    }


def timestamp(value):
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return float(value) if math.isfinite(value) else None
    if isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
            # The closure UTC formatter omits a timezone suffix in some versions.
            return parsed.replace(tzinfo=timezone.utc).timestamp() if parsed.tzinfo is None else parsed.timestamp()
        except ValueError:
            return None
    return None


def bounded_tail(source, max_bytes, max_records):
    with source.open("rb") as stream:
        before_stat = os.fstat(stream.fileno())
        before = before_stat.st_size
        start = max(0, before - max_bytes)
        if start:
            stream.seek(start - 1)
            previous = stream.read(1)
        else:
            previous = b"\n"
        stream.seek(start)
        data = stream.read(max_bytes)
        after_stat = os.fstat(stream.fileno())
        if (after_stat.st_size, after_stat.st_mtime_ns) != (before, before_stat.st_mtime_ns):
            raise RuntimeError("source size or modification time changed during bounded read")
    if start and previous != b"\n":
        skipped, separator, data = data.partition(b"\n")
        start += len(skipped) + len(separator)
    lines = deque(maxlen=max_records)
    offset = start
    for raw in io.BytesIO(data):
        lines.append((offset, raw))
        offset += len(raw)
    retained_hash = hashlib.sha256()
    for _, raw in lines:
        retained_hash.update(raw)
    def metadata(stat):
        return {"size_bytes": stat.st_size, "mtime_ns": stat.st_mtime_ns,
                "mtime_utc": datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat(),
                "device": stat.st_dev, "inode": stat.st_ino}
    return lines, {
        "source_bytes": before,
        "source_stat_before": metadata(before_stat),
        "source_stat_after": metadata(after_stat),
        "maximum_tail_bytes": max_bytes,
        "maximum_tail_records": max_records,
        "first_retained_byte_offset": lines[0][0] if lines else start,
        "retained_raw_bytes": sum(len(raw) for _, raw in lines),
        "retained_raw_sha256": retained_hash.hexdigest(),
        "retained_line_count": len(lines),
        "source_tail_is_complete_run": start == 0 and len(lines) < max_records,
    }


def summarize(source, max_bytes, max_records, top, predecessor_window):
    lines, scope = bounded_tail(source, max_bytes, max_records)
    records = []
    malformed = []
    keys = Counter()
    timestamp_keys = Counter()
    epochs = []
    segment = 0
    previous_ticket = None
    for index, (offset, raw) in enumerate(lines):
        try:
            value = json.loads(raw)
            if not isinstance(value, dict):
                raise ValueError("record is not an object")
        except (ValueError, UnicodeDecodeError) as error:
            if len(malformed) < 20:
                malformed.append({"tail_line_index": index, "byte_offset": offset,
                                  "error": str(error)})
            scope["invalid_records"] = scope.get("invalid_records", 0) + 1
            continue
        keys.update(value.keys())
        ticket = value.get("reservation_ticket")
        ticket = ticket if isinstance(ticket, int) and not isinstance(ticket, bool) else None
        if ticket is not None and previous_ticket is not None and ticket <= previous_ticket:
            segment += 1
        previous_ticket = ticket
        record = {key: value[key] for key in IDENTITY_KEYS if key in value}
        record.update({key: number(value.get(key)) for key in METRIC_KEYS})
        record.update(tail_line_index=index, byte_offset=offset, ticket_segment=segment)
        stamps = {key: value[key] for key in TIMESTAMP_KEYS if key in value}
        timestamp_keys.update(stamps.keys())
        if stamps:
            record["timestamps"] = stamps
            parsed = next((timestamp(stamps[key]) for key in TIMESTAMP_KEYS
                           if key in stamps and timestamp(stamps[key]) is not None), None)
            if parsed is not None:
                epochs.append(parsed)
        records.append(record)
    scope["valid_records"] = len(records)
    scope.setdefault("invalid_records", 0)
    by_kind = {}
    for kind in sorted({str(row.get("kind", "missing")) for row in records}):
        selected = [row for row in records if str(row.get("kind", "missing")) == kind]
        by_kind[kind] = {"records": len(selected), **{
            key: statistics(row[key] for row in selected) for key in METRIC_KEYS
        }}
    # Apply logs are ordered, but do not identify which earlier ticket stalled
    # each result. Keep bounded preceding candidates and label this explicitly.
    index_by_line = {row["tail_line_index"]: index for index, row in enumerate(records)}
    longest_ready = sorted(records, key=lambda row: row["ready_wait_seconds"] or 0, reverse=True)[:top]
    paired = []
    for row in longest_ready:
        index = index_by_line[row["tail_line_index"]]
        preceding = [candidate for candidate in records[max(0, index - predecessor_window):index]
                     if candidate["ticket_segment"] == row["ticket_segment"]]
        candidates = sorted(preceding, key=lambda item: item["compute_wall_seconds"] or 0, reverse=True)[:3]
        paired.append({"waiting_result": row, "preceding_compute_candidates": candidates})
    ea = [row for row in records if row.get("kind") == "deduplicate"]
    return {
        "schema_version": 1,
        "source": str(source.resolve()),
        "scope": scope,
        "observed_keys": dict(sorted(keys.items())),
        "timestamp_keys": dict(sorted(timestamp_keys.items())),
        "timestamp_range_epoch_seconds": [min(epochs), max(epochs)] if epochs else None,
        "timestamp_span_seconds": max(epochs) - min(epochs) if epochs else None,
        "ticket_segments_in_sample": segment + 1 if records else 0,
        "by_kind": by_kind,
        "equivalence_compute_seconds": statistics(row["compute_wall_seconds"] for row in ea),
        "longest_compute": sorted(records, key=lambda row: row["compute_wall_seconds"] or 0, reverse=True)[:top],
        "longest_ready_wait_with_preceding_candidates": paired,
        "malformed_examples": malformed,
        "interpretation_limits": [
            "This is a bounded chronological tail, not a random sample or a census of the run.",
            "Ready-wait measures compute completion to ordered application; it includes coordinator work and does not measure idle CPU time.",
            "Preceding slow computes are possible blockers, not proven causes; no task completion timeline can be reconstructed without appropriate timestamps.",
            "Ticket decreases mark inferred scheduler segments; adjacent source sessions can also reset tickets.",
            "Metrics count applied packets only; a stopped or failed unapplied straggler is absent.",
            "The predecessor window is bounded and may omit an earlier causal blocker.",
        ],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--max-bytes", type=int, default=MAX_BYTES)
    parser.add_argument("--max-records", type=int, default=MAX_RECORDS)
    parser.add_argument("--top", type=int, default=30)
    parser.add_argument("--predecessor-window", type=int, default=1024)
    args = parser.parse_args()
    if not 0 < args.max_bytes <= MAX_BYTES or not 0 < args.max_records <= MAX_RECORDS:
        parser.error("bounds must be positive and no greater than 64MiB / 100000 records")
    if not 0 < args.top <= 100 or not 0 < args.predecessor_window <= 4096:
        parser.error("top must be 1..100 and predecessor-window 1..4096")
    if args.output.resolve() == args.source.resolve() or (
        args.output.exists() and args.output.samefile(args.source)
    ):
        parser.error("output must differ from the read-only source")
    result = summarize(args.source, args.max_bytes, args.max_records, args.top, args.predecessor_window)
    result["command"] = [sys.executable, *sys.argv]
    result["working_directory"] = str(Path.cwd())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps({"output": str(args.output), "scope": result["scope"],
                      "equivalence_compute_seconds": result["equivalence_compute_seconds"]}))


if __name__ == "__main__":
    main()
