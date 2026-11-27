# Opt into crates.io ECOSYSTEM ranges

The `crates-io-semver-v1` profile interprets OSV `ECOSYSTEM` ranges only for exact
`crates.io` entries. Enable it explicitly; the original evaluator remains the
default so previously captured evidence continues to verify unchanged.

```sh
moon run lib/cli -- check --crates-io samples/installed.json samples/GHSA-wcg3-cvx6-7396.json
moon run lib/cli -- check --crates-io samples/fixed.json samples/GHSA-wcg3-cvx6-7396.json
```

Expected gates: 1 and 0. This real record uses ECOSYSTEM ranges: time 0.2.22
matches, while the fixed boundary 0.2.23 does not. OS/allocator/function conditions
are still preserved rather than evaluated. Omit the flag to retain the original
unsupported-range decisions. Provenance/license are in samples/SOURCES.md.

Library callers use `Snapshot::new(documents).with_crates_io()`, then the existing
`assess`, `capture` or `capture_bom` functions. The new method validates supported
ranges once and returns an independent snapshot. It does not mutate its argument.
The CLI flag is accepted immediately after `snapshot`, `check`, `capture`,
`check-cdx`, `check-bom`, `capture-bom` and the direct BOM SARIF commands.

## Explicit ordering boundary

Version syntax is strict SemVer, at most 256 UTF-16 units, with major/minor/patch
bounded by u64::MAX as in Cargo's semver Version. Prerelease identifiers use
SemVer precedence; build metadata does not affect range ordering. This matches
OSV's SemVer helper on the declared strict domain, rather than Rust Version's
total `Ord`, which includes build metadata. Leading `v`, shortened versions,
leading zeros and overflow are not coerced. Invalid installed versions stay
undetermined with a `query-is-not-crates-version` diagnostic.

Introductions/fixes, inclusive last_affected, open intervals, sentinel `0`, limits
and original event indices follow the existing documented interval rules. Invalid
supported boundaries, unknown transitions and ambiguous/contradictory events
reject profile activation with source pointers. Other ecosystems, custom/cased
ecosystem spellings, Git ranges and future range types keep their unsupported
evidence. Cargo requirement syntax (`^`, `~`, wildcard requirements) is not added.

References: [OSV ecosystem mapping](https://github.com/google/osv.dev/blob/d60b14dd943e35d7b790c8649da2804bd9e48a01/osv/ecosystems/_ecosystems.py),
[OSV SemVer helper](https://github.com/google/osv.dev/blob/d60b14dd943e35d7b790c8649da2804bd9e48a01/osv/ecosystems/semver_ecosystem_helper.py),
[Rust semver Version](https://docs.rs/semver/1.0.28/semver/struct.Version.html).
No upstream implementation or tests were copied.

## Snapshot and receipt compatibility

Default snapshots keep schema 1 and their exact original JSON. Explicit activation
produces schema 2 with `evaluation_profile: "crates-io-semver-v1"`; all original
advisory text, origins, unknown metadata and raw number tokens are retained.
`read_snapshot` admits only the documented schema/profile combinations.

The existing receipt envelopes frame the complete serialized snapshot, binding
this profile in their digest. Verification/replay reconstruct the stored profile;
they do not silently upgrade archived results. Old consumers reject schema 2
instead of interpreting it as schema 1. Reports/coverage carry the evaluation
label, and SARIF/Markdown retain the selected snapshot. Profile transitions are
reported by both comparison APIs and require review (gate 3) unless new affected
evidence already takes precedence (gate 1). Compare like profiles for ordinary
upgrade deltas. Unsupported BOM nodes remain in the outer gate.

## Independent validation

Install optional `semver==3.0.4` (BSD-3-Clause) and run:

```sh
moon run scripts/crates_oracle.mbtx pysemver
```

The runner checks 138 decisions using the external `pysemver compare` CLI over
six independently described intervals and 23 valid versions: prereleases, builds,
inclusive/exclusive bounds, open intervals and u64-scale core numbers. Inputs and
results remain under `_build`. It compares the strict-domain ordering used by
OSV, not OSV's permissive input coercion or an entire online database. Unit tests
separately cover limits, malformed inputs, unsupported ecosystems, replay,
profile substitution, deterministic snapshots and recovery. CI pins the oracle.
