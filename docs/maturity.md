# Maturity gates

Mooncakes publication is deferred. A prepared archive is a test artifact;
publication is a separate decision after the existing workflows are dependable.
Adding commands, ecosystems or commits alone does not establish maturity.

## Required regression gates

| Area | Acceptance evidence |
|---|---|
| Input integrity | Reject malformed JSON, duplicate decoded keys, unpaired UTF-16 and budget overflow with structured diagnostics. Preserve supported data and unknown source metadata exactly. |
| API round trips | Successful inventory exports fit the paired reader's budget, including escaping. Test the exact limit and one unit above it, plus direct API callers that bypass file decoding. |
| Evaluation | Test interval boundaries, prereleases, build metadata, unknown evidence and recovery. Compare the explicit crates.io profile against the pinned independent oracle. |
| Compatibility | Keep the frozen interface unchanged for compatible fixes. Replay the committed historical receipt and reject unknown evaluation profiles. |
| End-to-end behavior | Exercise CLI gates, corrupted receipts, independent pins and source locations. Recompute the eight saved public-project BOM assessments and four comparisons. |
| Portability | Run library tests on Wasm, Wasm-GC, JavaScript and native. Run file CLI workflows on Wasm and native across Linux, macOS and Windows CI. A compile check alone is insufficient. |
| Downstream use | Extract a fresh source archive and run the separate consumer on three portable backends. Keep registry consumption explicitly unverified until an approved publication is available. |

The [CI workflow](../.github/workflows/check.yml) executes these checks; inspect
the run for the exact source commit. The [real-project workflow](real-projects.md)
documents source pins, coverage accounting and offline replay. The
[release contract](release.md) documents API and receipt compatibility.

## Remaining evidence to gather before publication

1. Try additional producer versions and independently maintained downstream
   projects. Record the original input, expected behavior and producer version;
   turn every confirmed defect into a regression fixture with provenance.
2. Measure runtime and peak memory on representative inputs near the documented
   budgets before making capacity or performance claims. Current resource limits
   and passing correctness tests are not performance measurements.
3. Have a downstream developer complete inventory import, incomplete-evidence
   review, receipt handoff and replay using only the documentation. Record unclear
   diagnostics and workflow gaps, then fix them before expanding scope.

These are outstanding validation tasks, not claims of existing production use.
The current four historical source revisions exercise reproducibility and
incomplete coverage; they do not establish compatibility with every producer,
current project security or general production readiness.
