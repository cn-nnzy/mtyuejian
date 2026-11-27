# Review the same public projects with a second producer

This workflow checks **Trivy 0.76.2** against the four pinned historical exa/zoxide
source revisions used by the [Syft workflow](real-projects.md). It generates
unmodified CycloneDX 1.7 and SPDX 2.3, captures all listed nodes, verifies pinned
receipts, exports coverage/SARIF/Markdown and compares the two application releases.
Neither upstream project code nor build scripts are executed.

On Linux x86-64, reproduce both producers from fresh pinned sources:

```sh
moon run scripts/trivy_interop.mbtx --fetch-linux --fresh-syft
```

This first runs the complete Syft workflow. It then downloads the fixed Trivy
release and checks the release SHA-256 before extracting or executing it. To
reuse a complete Syft review directory with its original source checkouts:

```sh
moon run scripts/trivy_interop.mbtx /absolute/path/to/trivy SYFT_REVIEW_DIRECTORY
```

An optional final `native` selects the native file CLI on a configured C toolchain;
the default is Wasm. The runner verifies the source lock, manifest and MIT-license
digests against the committed configuration. It uses an isolated empty Trivy
configuration/cache, disables security scanners, DB/check/version updates,
dependency API lookups and telemetry. Initial acquisition needs network access;
this is SBOM generation and local evidence evaluation, not a Trivy vulnerability scan.

## Observed results for the pinned inputs

Both generated BOM formats have the following counts:

| Revision | Lock entries | Trivy catalog rows | Identified rows | Yuejian resolved | Unresolved | Lock identities not identified | Gate |
|---|---:|---:|---:|---:|---:|---:|---:|
| exa 0.10.0 | 43 | 43 | 43 | 41 | 4 | 0 | 1 |
| exa 0.10.1 | 45 | 45 | 44 | 42 | 5 | 1 | 1 |
| zoxide 0.7.9 | 98 | 83 | 83 | 82 | 3 | 15 | 1 |
| zoxide 0.9.0 | 106 | 106 | 106 | 105 | 3 | 0 | 3 |

The exa 0.10.1 catalog retains a root ID but supplies no name/version; both BOMs
contain that unnamed node. Yuejian retains it as unresolved, without reconstructing
identity from Trivy's private metadata. Every generated BOM node is counted:
`resolved + unresolved = catalog rows + 2`, including the source subject and
Cargo.lock application node. Known hits retain all incomplete evidence.

Trivy's [Cargo documentation](https://trivy.dev/docs/latest/coverage/language/rust/)
describes development-dependency filtering when reading lock and manifest together.
The runner records observed identity differences rather than claiming every
missing row has a particular cause. Each `*.scope.json` lists unidentified native
catalog entries and exact lock name/version pairs not identified by Trivy. All
native Trivy and complete Syft catalogs are retained for comparison. The scope
difference is not silently treated as an adapter success or a complete inventory.

The two selected RustSec records, historical interpretation and gates are those
documented in the Syft workflow. Passing these cases does not establish complete
vulnerability coverage, runtime inventory completeness or general Trivy compatibility.

## Review artifacts and replay

The printed `_build/yuejian-trivy-…` directory contains eight original BOMs,
receipts, reports, coverage views, located SARIF outputs and Markdown reviews;
four native catalogs, four baseline catalogs/scope views, four upgrade comparisons,
source pins, attribution/notices and a digest manifest. The success manifest is
written only after exact replay, rejection of a bad digest, escaping artifact path
and wrong receipt pin, followed by successful recovery.

```sh
moon run scripts/trivy_interop.mbtx --replay REVIEW_DIRECTORY
```

Replay requires only Yuejian and its installed dependencies. It does not need
Trivy, Syft, original source checkouts or advisory network access. Artifact paths
are confined after realpath resolution and bounded to 16 MiB. The manifest is
unsigned integrity evidence; an approval still needs independently trusted pins.

Linux CI executes fresh generation and retains a `trivy-review-COMMIT` artifact
for 14 days, excluding downloaded executables, archives and caches. Download and
extract that artifact before replaying its review directory. Generated UUIDs and
timestamps vary across scans; replay of one saved kit is deterministic.

References: [Trivy release](https://github.com/aquasecurity/trivy/releases/tag/v0.76.2),
[SBOM generation](https://trivy.dev/docs/latest/supply-chain/sbom/),
[CycloneDX 1.7](https://cyclonedx.org/docs/1.7/json/).
