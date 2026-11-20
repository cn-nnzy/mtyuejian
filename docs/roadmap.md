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

## Possible subsequent capabilities

1. Validate adoption with real downstream BOM producers and report consumers
   before broadening input profiles or claiming hosted UI compatibility.
2. Add individual ecosystem version-ordering profiles only with reference data,
   a documented identity convention and meaningful differential tests.

Git graph matching, online advisory database management, VEX policy, dependency
resolution, automated upgrades and exploitability analysis are not implemented.
No milestone is defined by a desired number of commits.
