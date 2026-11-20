# Sources and licenses

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

GitHub Actions uses actions/checkout, actions/setup-python and ilammy/msvc-dev-cmd (MIT) by
reference. Their source is not redistributed in this repository.
