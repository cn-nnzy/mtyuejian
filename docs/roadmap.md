# Capability roadmap

## Implemented in source 0.1.0

An inventory-to-assessment vertical slice: bounded strict input, exact package
identity, SEMVER/explicit-version assessment, incomplete evidence, withdrawn
records, deterministic JSON, lossless source snapshots, replay, a file CLI,
real-advisory end-to-end tests and a separate consuming module.

## Possible subsequent capabilities

1. Bind complete assessment inputs to content digests and add a verifier for a
   saved delivery. This would detect accidental changes; it would not authenticate
   the publisher by itself.
2. Add an inventory adapter for an existing SBOM producer, retaining unresolved
   identities and unsupported component metadata. Keep the evaluator independent.
3. Add individual ecosystem version-ordering profiles only with reference data,
   a documented identity convention and meaningful differential tests.

Git graph matching, online advisory database management, VEX policy, dependency
resolution, automated upgrades and exploitability analysis are not implemented.
No milestone is defined by a desired number of commits.
