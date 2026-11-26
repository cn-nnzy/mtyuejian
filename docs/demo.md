# Reproduce a complete offline review

After `moon update`, run from the repository root:

```sh
moon run scripts/demo.mbtx
```

The runner invokes the real CLI with the committed RustSec record, checks every
exit code, and writes UTF-8 files directly. It works in PowerShell and Unix
shells without redirection or a private service. `native` may replace the default
`wasm` argument when the host has the required C toolchain.

Each run creates a fresh `_build/yuejian-demo-…` directory. It contains:

| Artifact | Verified behavior |
| --- | --- |
| `before.delivery.json`, `before.report.json` | `time@0.2.22` matches; verification exits 1 |
| `fixed.delivery.json`, `fixed.report.json` | `time@0.2.23` does not match the supplied record; exits 0 |
| `unknown.delivery.json`, `unknown.report.json` | Missing evidence stays incomplete; exits 3 |
| `changes.json` | Fix delta exits 0 against the pinned example baseline |
| `before.sarif.json` | Finding location refers to the copied `samples/before-fix.json` |
| `review.md` | Readable review plus the complete replayable receipt |
| `before.coverage.json`, `partial.coverage.json` | Package-level coverage and actionable incomplete-evidence diagnostics |
| `partial.bom.delivery.json`, `partial.bom.report.json`, `partial.review.md` | Unsupported component is retained; assessment exits 3 |
| `manifest.json` | Final success marker, expected gates and byte SHA-256 of each artifact |

Original input samples and license/source notices are included. The illustrative
inventories are project-authored; the RustSec record is real, under CC0. This is
version evidence, not proof that an application is exploitable or safe.

The script exits 0 only after every expected result has been checked. Artifact
creation (`capture`, `review`) exits 0 even when the recorded verdict is 1 or 3.
An interrupted run may leave a directory, but has no `manifest.json` marker.
Receipt pins are obtained from these known demo inputs; a real approval workflow
must obtain its trusted pin separately. The manifest is not a signature.

Recheck an archived receipt from the repository, substituting the printed path:

```sh
moon run lib/cli -- verify _build/yuejian-demo-…/before.delivery.json
```

Expected exit: 1. Repeating the demo produces identical receipt content for the
same inputs. Directory names differ to avoid mixing runs. Tests and demonstration
outputs are generated under `_build` and are not source-controlled.
