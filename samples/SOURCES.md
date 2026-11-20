# Sample provenance

`RUSTSEC-2020-0071.json` is an unmodified public RustSec OSV export downloaded on
2026-11-19 from:

https://raw.githubusercontent.com/rustsec/advisory-db/osv/crates/RUSTSEC-2020-0071.json

- Advisory: https://rustsec.org/advisories/RUSTSEC-2020-0071.html
- License: CC0-1.0, explicitly recorded in `database_specific.license`.
- Embedded `modified`: `2024-06-05T14:00:17Z`.
- SHA-256: `fb2d3ab41d56f0bd4ee649b4c92c1131d7c7752949672a61308c6d662411983c`.

The raw branch URL can change. The committed bytes and digest identify this
fixture; the download date is not a claim that it was the newest aggregated OSV
revision. Its prose states that non-Unix targets are unaffected. The demo uses
only its version ranges and does not infer runtime applicability.

`installed.json`, `before-fix.json`, `fixed.json`, and `unknown.json` are project-authored inventory
examples for exercising that record. They do not describe a scanned real
application. Other synthetic advisories in tests and the consumer example use
the OSV `x_` local-ID prefix and fictional `example/demo` identities.
