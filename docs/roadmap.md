# Capability roadmap

## Implemented in source 0.1.0

An inventory-to-assessment vertical slice: bounded strict input, exact package
identity, SEMVER/explicit-version assessment, incomplete evidence, withdrawn
records, deterministic JSON, lossless source snapshots, replay, a file CLI,
real-advisory end-to-end tests and a separate consuming module. Self-contained
deliveries now bind the complete inputs and report with SHA-256 and verify the
saved result by recomputation.
Verified-delivery comparison now reports version/source changes, retained hits,
new findings, lost evidence and installation-identity substitutions.
CycloneDX 1.5/1.6 inventory import resolves a documented Cargo-PURL subset,
preserves original BOM text and keeps unsupported components in the outer gate.
SARIF export reuses sarifkit to expose version findings, explicit completeness
warnings and stable identities while retaining the full report and snapshot.
SPDX 2.3 Cargo package projection shares BOM assessment and SARIF workflows;
ambiguous identities and unexpanded external documents remain incomplete.
Full BOM deliveries preserve unresolved components through archived, recomputed
assessment handoffs, including SPDX and entirely unsupported inventories.
BOM receipt comparison accounts for unresolved identities and removed unknown
evidence, keeping the delta gate separate from the current absolute verdict.
Optional SARIF source indexing binds complete inventories and locates version
fields and unresolved BOM nodes in their actual retained JSON text.
Ordinary parsing also bounds cumulative pointer construction before allocation,
limiting repeated metadata path amplification without dropping fields.
Optional independent receipt pins bind verification and delta baselines to an
approved digest while preserving the original wire formats and verdicts.
Alias review correlates declared identifiers without merging decisions or
changing gates, using index links and a real RustSec/GitHub dual-source example.
Markdown review includes readable decisions, unresolved evidence, alias groups
and a complete replayable receipt; adaptive literal delimiters are tested with
an independent renderer and untrusted source formatting.
The one-command review kit validates real CLI gates and writes self-contained
receipts, reports and a byte-digest manifest. Source archives are unpacked into
fresh directories and checked through a separate consuming module. Syft 1.57.2
interoperability covers four generated CycloneDX/SPDX cases, retaining directory
and file subjects as unresolved rather than silently discarding them.
Coverage review counts installation IDs independently of source decisions and
provides source-linked next steps for each incomplete-evidence category, without
changing saved receipt formats or hiding unresolved artifacts.
Complete-project review now checks four pinned exa/zoxide source revisions,
accounts for every lock package across producer formats and resolved/unresolved
assessment entries, and replays eight receipts and four upgrade comparisons.
The opt-in crates.io ECOSYSTEM profile is bound into schema-2 snapshots and
receipts, with conservative profile-change deltas and a pinned independent oracle.

## Possible subsequent capabilities

1. Validate additional producers and hosted report consumers against the pinned
   complete-project workflow before broadening compatibility claims.
2. Extend ecosystem ordering only with reference data and differential tests.
   crates.io ECOSYSTEM ordering is now an explicit, versioned snapshot profile;
   npm and other ecosystems still require their own complete identity/ordering work.

Git graph matching, online advisory database management, VEX policy, dependency
resolution, automated upgrades and exploitability analysis are not implemented.
No milestone is defined by a desired number of commits.
