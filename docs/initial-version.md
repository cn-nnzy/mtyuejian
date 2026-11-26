# Source 0.1.0 acceptance

The initial project is an offline version-evidence library with a file CLI and
an end-to-end review workflow. It is a source version, not a Mooncakes release.

| Available now | Deliberate boundary |
| --- | --- |
| Strict OSV reading, SEMVER intervals and explicit versions | ECOSYSTEM/GIT/unknown range semantics stay undetermined |
| Deterministic assessment, raw-source snapshots and SHA-256 receipts | Integrity and replay do not authenticate a publisher |
| Independent pins and conservative receipt comparison | Approval pins must come from a trusted external source |
| Cargo projection from CycloneDX 1.5/1.6 and SPDX 2.3 | Unsupported nodes stay visible and prevent a complete verdict |
| Located SARIF, source alias review and lossless Markdown | No hosted viewer or exploitability claim |
| Public consumer, complete demo kit and archive smoke check | Dependency acquisition still uses the MoonBit cache/registry |
| Fixed-version Syft producer integration | Four documented cases; not all producer formats or applications |

The core has 139 unit/documentation tests per supported backend. The CLI runner
checks 124 scenarios, including malformed UTF-8/JSON, recovery after errors,
receipt replacement/pinning, unknown BOM nodes and source location binding.
Independent tools validate the SARIF schema and render untrusted Markdown.

To repeat the main local checks with MoonBit stable:

```sh
moon update
moon fmt --check
moon fmt --check scripts/demo.mbtx scripts/package_smoke.mbtx scripts/syft_interop.mbtx
moon info --target all
git diff --exit-code -- lib/pkg.generated.mbti
moon check --target all --deny-warn
moon test --target wasm --deny-warn
moon test --target wasm-gc --deny-warn
moon test --target js --deny-warn
moon run scripts/e2e.mbtx wasm
moon run scripts/demo.mbtx
moon run scripts/package_smoke.mbtx
```

The source-archive step needs Python 3; [producer integration](producer-interop.md)
and independent [SARIF](sarif.md)/[Markdown](review-markdown.md) validation document
their additional tools. See [the CI workflow](../.github/workflows/check.yml) for
the exact Linux, macOS and Windows jobs, including **executed** native tests and
native CLI scenarios. A local native compilation check alone is not a native
runtime result. Local Windows validation used MoonBit stable 0.1.20261119 with
moonc 0.10.22+124d61d05; local native execution was not available without MSVC.

No network advisory synchronization, graph matching, VEX, dependency resolution,
upgrade automation, npm ordering profile or exploitability evaluation is included.
The [roadmap](roadmap.md) records possible later work. Changing a package name or
accepting additional PURLs without correct version semantics is not ecosystem
support. Sources, reused dependencies and fixture licenses are recorded in
[THIRD_PARTY.md](../THIRD_PARTY.md) and [samples/SOURCES.md](../samples/SOURCES.md).
