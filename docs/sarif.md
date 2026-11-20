# Export assessments for SARIF consumers

The exporter reuses [Derk2006/sarifkit 0.1.3](https://mooncakes.io/docs/Derk2006/sarifkit@0.1.3)
for SARIF 2.1.0 construction. Yuejian owns the version-evidence mapping,
completeness rules, stable identities and source retention.

## Runnable workflows

```sh
moon run lib/cli -- capture samples/installed.json samples/RUSTSEC-2020-0071.json > delivery.json
moon run lib/cli -- sarif delivery.json samples/installed.json > assessment.sarif
moon run lib/cli -- sarif-cdx samples/cargo-partial.cdx.json samples/cargo-partial.cdx.json samples/RUSTSEC-2020-0071.json > bom.sarif
```

`capture` exits 0; the two export commands exit 1 and 3 respectively. Export
retains the assessment gate. In CI, save stdout as an artifact while preserving
the process exit. Input diagnostics still go to stderr with exit 2 and no report.
The delivery command verifies and recomputes its input before export. BOM export
uses the outer completeness gate, including unsupported component identities.

Library users call `Assessment::to_sarif(inventory_uri=...)` or
`BomAssessment::to_sarif(bom_uri=...)`. These return independent JSON values and
raise `InputError` for an unsupported artifact URI or failed projection check.

## Mapping

| Rule | Condition | SARIF kind / level |
|---|---|---|
| YJ001 VersionMatch | Known version match | fail / error |
| YJ001 VersionMatch | Version not matched in the supplied snapshot | pass / none |
| YJ002 EvidenceCompleteness | Undetermined, withdrawn, no advisory, unscoped entry, or incomplete evidence alongside a known hit | fail / warning |
| YJ003 BomIdentity | Unresolved BOM component or empty component set | fail / warning |

Warnings identify evidence problems, not confirmed vulnerabilities. Error level
is a gate priority, not CVSS severity or a claim of exploitability. Pass results
are included even when a consumer chooses to hide them. A known hit with partial
evidence produces both YJ001 and YJ002 results. Source pointers and event indices
remain in the original decision, serialized in result properties.

Every run includes these structured properties:

- `yuejian/profile`: `assessment-sarif-v1`;
- `yuejian/exit_code`: the original assessment or outer BOM gate;
- `yuejian/report`: the complete original assessment JSON, including all decisions
  and unresolved/unscoped entries;
- `yuejian/snapshot`: the lossless source snapshot of the supplied advisories.

For BOMs, the report also contains exact original BOM text. This preserves unknown
metadata and numeric tokens. The exported SARIF is a report projection; use the
delivery API for verified replay. Generic SARIF tools that discard custom
properties may discard Yuejian's retained evidence; retain the original artifact.

## Identities and locations

The `partialFingerprints["yuejian/identity/v1"]` value uses domain-separated
SHA-256 over a JSON-framed tuple. Decision identities contain the rule, installation
ID, ecosystem, package name and primary advisory ID. Version, outcome, source label
and input URI do not affect identity, so an upgrade keeps its YJ001 identity.
Unscoped entries use advisory ID and pointer; unresolved components use their
ID or pointer. Reordering components without IDs may change their identity.
These are correlation hints, not proof of authenticity or a replacement for
`compare_deliveries`.

The caller supplies a relative URI using ASCII letters, digits and `-._~/`.
Absolute paths, schemes, backslashes, percent escapes, Unicode, spaces, query or
fragment characters and empty/dot/parent segments are rejected. The URI labels
the caller's actual input artifact; export does not open or verify that path.
Default locations refer to the artifact without source coordinates. The optional
[source-location workflow](source-locations.md) binds actual input and adds regions.
Unscoped advisory entries have no fabricated inventory location. There is no automatic
upload, line annotation or claim that every hosted code-scanning UI accepts this
profile. Runtime applicability, severity enrichment and fix suggestions are absent.

## Independent schema check

```sh
moon run scripts/e2e.mbtx wasm
python -m pip install check-jsonschema==0.39.0
moon run scripts/sarif_schema.mbtx
```

The end-to-end run writes `_build/yuejian-sarif-example.json` and
`_build/yuejian-bom-sarif-example.json`. The second script downloads the OASIS
schema at revision `a560296ca8c921f3bdb8d4a8db57ab83dae968a7`, verifies SHA-256
`c3b4bb2d6093897483348925aaa73af03b3e3f4bd4ca38cef26dcb4212a2682e`, then checks both
reports and three located variants with the independent validator. A deliberately invalid SARIF version must
be rejected too. CI runs this check on Linux in addition to all platform tests.
For offline use with installed dependencies, pass a matching local schema and an
optional validator executable: `moon run scripts/sarif_schema.mbtx SCHEMA.json VALIDATOR`.

The semantic mapping follows the [OASIS SARIF specification](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html).
Schema validation complements the domain tests; it does not establish hosted UI
compatibility or validate the accuracy/completeness of supplied vulnerability data.
