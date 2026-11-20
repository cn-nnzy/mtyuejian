# Review linked advisory identifiers without suppressing evidence

`Delivery::alias_review` and `BomDelivery::alias_review` correlate records whose
primary IDs or declared OSV aliases overlap. They expose the transitive source
groups for human review while retaining every original decision and the original
assessment gate. This is source correlation, not a unique-vulnerability count,
an assertion that sources agree, or a rule to waive one record's finding.

```sh
moon run lib/cli -- capture samples/installed.json samples/RUSTSEC-2020-0071.json samples/GHSA-wcg3-cvx6-7396.json > linked.delivery.json
moon run lib/cli -- aliases linked.delivery.json
```

Capture exits 0 and review exits 1. The real RustSec and GitHub records share a
CVE identifier. Their SEMVER and unsupported ECOSYSTEM evidence both remain:
the two-package input still has four source decisions, with a known match and
incomplete evidence in the same group. Version-only assessment does not infer
operating-system applicability from either record's prose. Fixture attribution
and license are in [sample provenance](../samples/SOURCES.md).

`aliases-bom BOM.delivery.json` verifies a full BOM receipt and preserves its
outer gate, including unresolved components. The JSON `alias-review-v1` view
contains the complete original `report` and lossless `snapshot`, plus:

- Groups sorted by the first primary ID, with sorted unique identifiers.
- Record metadata with `snapshot_index`, pointing into `snapshot.documents`.
- Shared-identifier links using `record_indices` into that same snapshot. Index
  links avoid repeatedly expanding long advisory IDs for every alias.
- `decision_indices` into `report.decisions`, or `report.assessment.decisions`
  for a BOM, as indicated by `assessment_pointer`. Every decision appears in
  exactly one group or `unassigned_decision_indices`; no-advisory rows stay there.
- Active unscoped entries and flags for scoped decisions, known matches and
  incomplete evidence. Empty groups make no negative vulnerability claim.

Primary IDs are distinct source records. Case, spelling and Unicode are exact;
`related` metadata does not establish an alias link. Repeated/self aliases do not
fabricate additional sources. Withdrawn records stay visible. An unsupported or
contradictory source is not replaced by whichever record produces a preferable
outcome. Reversed input ordering and verified replay produce the same view.

The snapshot's existing 64-record, 128-alias-per-record and total-source budgets
bound this projection. It adds no generic graph API, external database, VEX
policy or automatic record deduplication. Original receipt formats are unchanged.
