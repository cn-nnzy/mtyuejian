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

`cargo.cdx.json`, `cargo-fixed.cdx.json` and `cargo-partial.cdx.json` are
project-authored CycloneDX input examples using the same time-version boundary.
The extra npm identity is fictional and demonstrates unresolved evidence. These
files and all newly authored tests use the project's Apache-2.0 license.

`cargo.spdx.json` is a project-authored SPDX representation of the same time
example, not output claimed from a third-party scanner. It contains no copied
application code. The SPDX metadata is offered under CC0-1.0 as declared by its
`dataLicense`; the authored implementation and tests use Apache-2.0.

`GHSA-wcg3-cvx6-7396.json` is an unmodified GitHub Advisory Database record,
downloaded 2026-11-20 from:
https://raw.githubusercontent.com/github/advisory-database/main/advisories/github-reviewed/2021/08/GHSA-wcg3-cvx6-7396/GHSA-wcg3-cvx6-7396.json

- Publisher: GitHub Advisory Database and its community contributors; upstream
  advisory: https://github.com/time-rs/time/security/advisories/GHSA-wcg3-cvx6-7396
  (jhpratt; finder quininer).
- License: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), per
  https://github.com/github/advisory-database/blob/main/LICENSE.md.
- Embedded `modified`: `2024-06-10T18:40:10Z`.
- SHA-256: `52d3d82823418b3565d651ac1702cb523d9a245bde38f6d37582f26ef2adf84a`.
- No changes were made. The branch URL may change; the stored bytes identify this
  fixture. Its ECOSYSTEM ranges remain unsupported and require review. Alias
  links to the RustSec sample do not erase the distinct source decisions.

## Producer input fixtures

`producer/before/Cargo.lock` and `producer/fixed/Cargo.lock` are project-authored
minimal cataloger inputs (Apache-2.0), not copied Cargo resolutions. They contain
the real package/version names used in the RustSec boundary example; they do not
claim to describe a buildable application or complete dependency graph. The
Syft interoperability runner generates its own BOM outputs under `_build`.

## Complete-project advisory snapshots — 2026-11-26

Two unmodified RustSec OSV exports were downloaded for the historical project
workflow. Both explicitly declare CC0-1.0 in `database_specific.license`:

| File | Unchanged source | SHA-256 |
| --- | --- | --- |
| RUSTSEC-2021-0139.json | https://raw.githubusercontent.com/rustsec/advisory-db/osv/crates/RUSTSEC-2021-0139.json | `94403572b62224ec8016a0c8a546d3bbf67061d9783ca6032090a143906f80cb` |
| RUSTSEC-2021-0145.json | https://raw.githubusercontent.com/rustsec/advisory-db/osv/crates/RUSTSEC-2021-0145.json | `8a03b873f4ebb59faeec5169534ee7e12a4bbddd5490867c7b74d54d7567b229` |

The first record is informational: ansi_term is unmaintained. Its embedded
modified time is 2023-09-06T22:52:31Z. A range match is not an exploitability claim.
The second concerns an atty unaligned read with Windows/allocator conditions;
its modified time is 2023-07-08T12:30:19Z. Only version evidence is evaluated.
These selected records are not a complete vulnerability database, nor a claim
about the latest security state of either upstream application.

`real-projects.json` is project-authored configuration under Apache-2.0. It pins
four full source commits, lock/manifest/license byte digests and expected results.
Upstream exa (https://github.com/ogham/exa, Benjamin Sago) and zoxide
(https://github.com/ajeetdsouza/zoxide, Ajeet D'Souza) are MIT. The runner retains
their original license notices in downloaded checkouts; upstream code and locks
are not distributed as this repository's own source. Tag-object IDs for zoxide
are deliberately not used as commit IDs: the configuration records peeled commits.
