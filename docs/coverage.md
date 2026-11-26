# Review coverage and incomplete evidence

`Assessment::coverage()` and `BomAssessment::coverage()` return the independent
`coverage-review-v1` JSON view. Existing assessment JSON, receipt bytes/digests,
verification and exit codes are unchanged. Markdown reviews now include these
counts and next steps before the complete original receipt.

```sh
moon run scripts/demo.mbtx
moon run lib/cli -- coverage _build/yuejian-demo-…/before.delivery.json
moon run lib/cli -- coverage-bom _build/yuejian-demo-…/partial.bom.delivery.json
```

Use the actual directory printed by the demo. Both commands first verify and
recompute their receipt. They return the underlying gate (0, 1 or 3); malformed
receipts/usage return 2. Both accept `--expected-sha256 SHA256` before the path
for an independently approved pin. Coverage is not an authenticity claim.

## Counting contract

`counts.resolved_packages` counts installation IDs once, even when many source
records produce decision rows for one installation. The four package counts
partition this total, in precedence order:

1. `known_match_packages`: at least one affected decision.
2. `no_advisory_packages`: no supplied matching record.
3. `undetermined_packages`: other incomplete or withdrawn source evidence.
4. `not_matched_packages`: all relevant source decisions are complete negatives.

`packages_with_incomplete_evidence` overlaps the partition: a known match can
also have unsupported evidence. `decision_rows` counts package/source decisions;
it is not a CVE count. `unresolved_entries` counts retained BOM entries, including
external documents and empty-inventory placeholders; it is not a component count.
`unscoped_advisory_entries` counts active source entries with missing identities.
No percentage is presented as a safety score or whole-database coverage claim.

Each package includes its status, incomplete flag and indices into the original
report's decisions. `assessment_pointer` is empty for an inventory report and
`/assessment` for a BOM report. Every diagnostic includes a category, original
code, source origin/path, report pointer, optional identity/type, explanation and
`next_action`. Inventory locations are null when the original location cannot
be established; no location is invented from a sorted array index.

## Diagnostic categories

Missing advisory, unsupported version rule, version syntax, withdrawn advisory,
missing version evidence, missing identity, identity conflict, unsupported identity,
unsupported component, artifact node, external inventory and empty inventory are
reported separately. `diagnostic_counts` counts diagnostic rows, not packages.

CycloneDX `file` components and SPDX packages declaring purpose `FILE` receive
the artifact category when their retained diagnostic is type/PURL related.
Only CycloneDX `/metadata/component` is identified as the format's BOM subject;
SPDX relationships/names are not guessed into a subject role. File/directory
artifacts stay unresolved and keep the outer gate incomplete. This view adds no
ignore list, automatic identity correction, record suppression or online lookup.
Opaque/future SPDX purpose metadata keeps its previous admission behavior.

Diagnostics are deterministic and returned as fresh views. Original unknown
metadata and unsupported nodes remain in the receipt. Remediation instructions
describe evidence to obtain or producers to correct; they do not assert that
upgrading a version makes an application safe.
