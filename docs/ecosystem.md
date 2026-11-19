# Scope review — 2026-11-19

Yuejian adds offline OSV version-evidence assessment to existing MoonBit tooling.
It does not claim ecosystem uniqueness or independent invention of OSV/SemVer
algorithms. This is a bounded review of public projects and known local work.

| Project | Existing API boundary | Relationship |
|---|---|---|
| [cogna-dev/sbom](https://mooncakes.io/docs/cogna-dev/sbom) | scan_cargo, export_spdx, export_cyclonedx; ordinary version constraints | Supplies dependency inventory; Yuejian does not generate SBOMs or parse lockfiles |
| [VexAudit](https://github.com/q0w1ertyuiop/VexAudit) | read_openvex, read_trivy_json, reconcile | Reviews findings and VEX claim coverage; Yuejian evaluates version evidence before that workflow |
| [moonbit-license-audit](https://mooncakes.io/docs/clbbbb/moonbit-license-audit) | SPDX expression and project license metadata review | Different evidence and policy; no license audit in Yuejian |
| [OSV-Scanner](https://github.com/google/osv-scanner) | Mature Go scanner using OSV data | Demand/reference workflow; Yuejian is an embeddable MoonBit core, not a feature-equivalent replacement |

Search terms included MoonBit/Mooncakes with OSV, vulnerability, advisory,
scanner, SEMVER, SBOM and VEX. The review inspected Mooncakes API documents,
GitHub READMEs, known local interfaces and official specifications. Unpublished,
unindexed and subsequently changed projects remain possible overlaps. Recheck
this boundary before adding lockfile scanning, online feeds or VEX policy.

The project follows the documented OSV format and SemVer precedence. The public
API centers on advisory snapshots, installed packages, assessments and evidence;
the private JSON reader and version comparator are implementation details.
