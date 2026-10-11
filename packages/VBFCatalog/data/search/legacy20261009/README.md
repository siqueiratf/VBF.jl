# Recovered historical discovery plan

[replay.toml](replay.toml) records the input digest, construction parameters,
validation counts, retention decisions and executable search/resume commands.
[parents.tsv](parents.tsv) supplies all 11,405 recovered historical parent LUTs,
in completion-ledger order. It is scientific input data, not a second catalog.

The catalog contains corpus `legacy20261009_n8`: 111,009 verified quadratic APN
representatives with distinct separating signatures, absent from the expanded
public baseline before registration. The full recovered archive validation checked
114,062 records and retained 111,835 exact LUTs, including matching-signature
candidates whose equivalence is unresolved. Literature-wide novelty is unresolved.

The local ignored `validated/` directory holds the full validation database,
frozen inputs, source snapshots and publication receipt. `sources.toml` records
original input paths and byte hashes. Historical paths refer to the old layout;
the APN archive now lives under `../../research/`. The intermediate accepted TSV
can be regenerated from compact members in the main tracked catalog on rebuild.

A one-parent VBFSearch replay reproduced all 25 historical child signatures.
The full recovered plan has not been replayed, and its exhaustion would apply
only to those finite construction spaces. New replay results will often match
the now-registered archive, so a zero new-to-catalog count is expected for them.
