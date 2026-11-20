# Review changes between assessments

`compare_deliveries(before, current)` accepts only opaque captured or verified
deliveries. The file command validates and recomputes both deliveries first:

```sh
moon run lib/cli -- capture samples/fixed.json samples/RUSTSEC-2020-0071.json > before.delivery.json
moon run lib/cli -- capture samples/before-fix.json samples/RUSTSEC-2020-0071.json > current.delivery.json
moon run lib/cli -- changes before.delivery.json current.delivery.json
```

Save artifact stdout as UTF-8. The last command exits 1: installation `time`
changes from 0.2.23 to 0.2.22 and becomes affected by the same source advisory.
Reversing the two inputs exits 0 and labels the transition `no-longer-matched`,
not universally fixed. The automated end-to-end suite exercises both directions,
retained findings, invalid deliveries and recovery.

## Matching and evidence

Rows align by exact installation ID, ecosystem, package name and primary advisory
ID. Versions may change. Aliases do not establish equivalence. Reusing one
installation ID for a different package produces an explicit identity-change
record and requires review. Keys are framed as JSON arrays, so arbitrary names
and separators cannot collide by concatenation.

Each entry includes both decision views, a category, and causes such as a changed
package version or advisory source/origin. Categories are `added`, `removed`,
`newly-affected`, `no-longer-matched`, `became-incomplete`, `changed`, and
`unchanged`. Both delivery digests remain in the report. Keep those deliveries
to inspect the full original advisory text; this report is a derived view.

## Two different gates

The change gate is deliberately separate from the current assessment gate:

- 1: at least one newly affected row, including a newly added affected row.
- 3: no new known hit, but current evidence is incomplete, a prior advisory row
  disappeared, an installation disappeared, or an ID changed package identity.
- 0: neither of those conditions.

An unchanged affected row therefore permits delta exit 0 while
`current_exit_code` remains 1. This is a review of changes, not a waiver or an
absolute release-safety check. A baseline never forgives uncertainty: current
unknown ranges, missing advisories, withdrawn records and unscoped entries still
require review. Removing an advisory cannot be reported as a fix. Replacing an
old `no_advisory` placeholder with concrete evidence for the same installation
does not itself count as lost advisory evidence.

Input errors return CLI exit 2 with no partial change report. Report order is
deterministic and reading its JSON cannot alter either delivery.
