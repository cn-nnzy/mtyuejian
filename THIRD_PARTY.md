# Sources and licenses

- crates.io evaluation references OSV's ecosystem mapping and SemVer helper at
  https://github.com/google/osv.dev/tree/d60b14dd943e35d7b790c8649da2804bd9e48a01/osv
  (Apache-2.0), and Rust semver 1.0.28's documented u64 syntax and precedence
  (MIT OR Apache-2.0, https://docs.rs/semver/1.0.28/semver/struct.Version.html).
  No implementation or upstream tests were copied. The independent oracle invokes
  python-semver 3.0.4's CLI (BSD-3-Clause,
  https://github.com/python-semver/python-semver/tree/3.0.4); no Python code is
  authored or vendored here. The existing SemVer/interval implementation is reused
  within a deliberately strict, explicitly versioned profile.

- Project code: Apache-2.0. No third-party implementation code was copied into
  the library. The private algorithms were written against the references below.
- OSV format and evaluation semantics:
  https://ossf.github.io/osv-schema/ (version 1.9.2, 2026-10-13), with source at
  https://github.com/ossf/osv-schema (Apache-2.0). This project implements a documented subset,
  including a stricter admission policy for ambiguous/redundant transitions.
- SemVer 2.0.0: https://semver.org/spec/v2.0.0.html. The precedence sequence used
  in tests comes from section 11 (specification by Tom Preston-Werner, CC BY 3.0);
  other boundary cases and the generated integer
  oracle were authored for this project.
- RustSec sample: CC0-1.0. Exact source, retrieval date and content digest are in
  [samples/SOURCES.md](samples/SOURCES.md). Its full original attribution remains
  in the committed JSON. No vulnerability exploit or third-party application
  source is bundled.
- GitHub Advisory Database sample `GHSA-wcg3-cvx6-7396`: CC BY 4.0.
  Attribution, unchanged-source URL and digest are recorded in samples/SOURCES.md;
  this fixture is outside the project's Apache-2.0 source-code license.
- Runtime dependency `moonbitlang/async@0.22.10`: Apache-2.0,
  https://github.com/moonbitlang/async. Used by the file CLI and automation;
  the library package does not import the async runtime.
- MoonBit core library: Apache-2.0,
  https://github.com/moonbitlang/core. JSON string decoding/encoding, collections
  and test facilities are reused through imports, not vendored source.
- `moonbitlang/x@0.5.7`: Apache-2.0, https://github.com/moonbitlang/x.
  Its crypto package computes SHA-256 for assessment deliveries and SARIF identities. The digest is
  framing/integrity evidence, not a signature or publisher-authentication claim.
- `Derk2006/sarifkit@0.1.3`: MIT, https://github.com/Derk2006/sarifkit.
  Imported for SARIF builders, typed results, locations, serialization and checks.
  Yuejian adds domain mappings and retained evidence through SARIF properties.
- OASIS SARIF 2.1.0 plus Errata 01:
  https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html.
  The independent validation script downloads the official repository schema from
  https://github.com/oasis-tcs/sarif-spec/blob/a560296ca8c921f3bdb8d4a8db57ab83dae968a7/sarif-2.1/schema/sarif-schema-2.1.0.json.
  No schema or specification text is redistributed. `check-jsonschema@0.39.0`
  (Apache-2.0, https://github.com/python-jsonschema/check-jsonschema) is an optional
  independent validation tool used by the Linux CI job.
- Apache-2.0 license text: https://www.apache.org/licenses/LICENSE-2.0.txt.
- SPDX 2.3 package-information reference:
  https://spdx.github.io/spdx-spec/v2.3/package-information/.
  Used for a restricted Cargo inventory consumer; no upstream schema, prose,
  implementation or test fixtures are redistributed.
- JSON Pointer escaping follows RFC 6901 section 3:
  https://www.rfc-editor.org/rfc/rfc6901#section-3.
  Source-location and repeated-escape regression tests were authored locally;
  no RFC text or implementation was copied.
- CycloneDX 1.6 JSON reference: https://cyclonedx.org/docs/1.6/json/;
  Cargo Package URL definition:
  https://github.com/package-url/purl-spec/blob/main/docs/types/definitions/cargo-definition.md.
  Used as behavioral references for a restricted inventory projection. No schema,
  specification text or upstream implementation is redistributed.

GitHub Actions uses actions/checkout, actions/setup-python, actions/upload-artifact and ilammy/msvc-dev-cmd (MIT) by
reference. Their source is not redistributed in this repository.

The optional producer integration invokes Syft 1.57.2 (Apache-2.0),
https://github.com/anchore/syft/releases/tag/v1.57.2. Its Linux x86-64 download
is checked against the SHA-256 from that release's `syft_1.57.2_checksums.txt`.
No Syft code or binary is redistributed. Cargo lock inputs in samples/producer
were authored here under Apache-2.0; generated BOMs remain build artifacts.

The second producer workflow invokes Trivy 0.76.2 (Apache-2.0),
https://github.com/aquasecurity/trivy/releases/tag/v0.76.2. Linux x86-64 and local
Windows x86-64 archives were checked against that release's
`trivy_0.76.2_checksums.txt` before extraction. No Trivy implementation or binary
is redistributed. Generated BOMs and native catalogs remain review artifacts;
upstream MIT source notices and CC0 advisory attribution accompany the kit.
CycloneDX 1.7 component identity/traversal was reviewed against the official JSON
reference https://cyclonedx.org/docs/1.7/json/ and Apache-2.0 schema at
https://github.com/CycloneDX/specification/blob/4b3f59453366e27c8073fd24e98bf21ef8892c8e/schema/bom-1.7.schema.json.
No upstream schema, prose, test data or implementation was copied. The 1.7 and
empty-name regression inputs were authored here after observing Trivy output.

The complete-project workflow fetches historical exa and zoxide sources (both
MIT) into build artifacts only, at the exact commits and primary-file digests in
samples/real-projects.json. Upstream license files remain in each checkout.
No upstream implementation or lock file is vendored into this module.
Two additional unmodified RustSec OSV records are CC0-1.0; source URLs, retrieval
date and byte digests are recorded in samples/SOURCES.md. The ansi_term record is
an informational maintenance advisory, not a claimed exploitable vulnerability.

Markdown behavioral references are the CommonMark 0.31.2 code-span and fenced-block
rules, https://spec.commonmark.org/0.31.2/ (specification by John MacFarlane,
CC BY-SA 4.0). No prose or test fixtures were copied. The independent rendering
check imports no renderer code: it invokes `commonmark@0.9.1`'s `cmark` CLI
(BSD-3-Clause, https://github.com/readthedocs/commonmark.py). This optional Linux
CI dependency is pinned as a regression oracle; generated reviews do not require it.
