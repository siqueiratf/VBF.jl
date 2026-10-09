"""Download only pinned survey inputs; upstream bytes must match sources.tsv.

Usage: python fetch_sources.py DOWNLOAD_DIRECTORY
PDFs and generated datasets belong in an ignored results directory.
"""
import csv
import hashlib
from pathlib import Path
import sys
import urllib.request


def fetch(root):
    root = Path(root)
    with Path(__file__).with_name("sources.tsv").open() as manifest:
        for item in csv.DictReader(manifest, delimiter="\t"):
            path = root / item["file"]
            if path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == item["sha256"]:
                continue
            request = urllib.request.Request(item["url"], headers={"User-Agent": "VBF-literature-audit"})
            with urllib.request.urlopen(request, timeout=120) as response:
                data = response.read()
            if hashlib.sha256(data).hexdigest() != item["sha256"]:
                raise ValueError(f"Source changed: {item['url']}")
            path.parent.mkdir(parents=True, exist_ok=True)
            temporary = path.with_suffix(path.suffix + ".tmp")
            temporary.write_bytes(data)
            temporary.replace(path)
            print(item["file"])


if __name__ == "__main__":
    fetch(sys.argv[1])
