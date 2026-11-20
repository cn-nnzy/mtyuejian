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
- Runtime dependency `moonbitlang/async@0.22.10`: Apache-2.0,
  https://github.com/moonbitlang/async. Used by the file CLI and automation;
  the library package does not import the async runtime.
- MoonBit core library: Apache-2.0,
  https://github.com/moonbitlang/core. JSON string decoding/encoding, collections
  and test facilities are reused through imports, not vendored source.
- `moonbitlang/x@0.5.7`: Apache-2.0, https://github.com/moonbitlang/x.
  Its crypto package computes SHA-256 for assessment deliveries. The digest is
  framing/integrity evidence, not a signature or publisher-authentication claim.
- Apache-2.0 license text: https://www.apache.org/licenses/LICENSE-2.0.txt.
- CycloneDX 1.6 JSON reference: https://cyclonedx.org/docs/1.6/json/;
  Cargo Package URL definition:
  https://github.com/package-url/purl-spec/blob/main/docs/types/definitions/cargo-definition.md.
  Used as behavioral references for a restricted inventory projection. No schema,
  specification text or upstream implementation is redistributed.

GitHub Actions uses actions/checkout (MIT) and ilammy/msvc-dev-cmd (MIT) by
reference. Their source is not redistributed in this repository.
