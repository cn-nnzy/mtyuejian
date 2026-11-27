# Runtime and memory regression baseline

The benchmark uses a release Wasm build of a separate consumer that calls the
public library API. It builds once and runs the compiled program directly in
Moonrun. Linux CI records a JSON report and checks elapsed time and peak
resident memory for each workload. The checks are intended to catch large
regressions on shared runners.

Generate the [Trivy review kit](trivy-interop.md) first, then use the
`zoxide-0.7.9.cdx.json` from that kit:

```sh
moon run scripts/performance.mbtx REVIEW_DIRECTORY/zoxide-0.7.9.cdx.json
```

On Linux x86-64, append `--linux-ci` with GNU Time installed at
`/usr/bin/time` to measure process RSS and apply the CI thresholds. The
report records the source commit, toolchain, input hash and raw samples.
Use the same backend, toolchain, fixture and host configuration when
comparing measurements across commits.

| Workload | Timed operations | CI median limit in ms per operation | CI peak RSS limit |
| --- | --- | --- | --- |
| Trivy zoxide 0.7.9 | Parse, assess, capture, replay | 25, 3, 15, 35 | 128 MiB |
| Generated BOM with 1,024 components and metadata | Parse, assess, capture, replay | 100, 30, 100, 180 | 256 MiB |
| Generated BOM with exactly 1,048,576 UTF-16 units | Parse | 120 | 128 MiB |

The real workload uses the checked-in historical atty advisory. Generated
workloads alternate two installed versions of time with a checked-in advisory
and keep metadata in the original input. The exact JSON size workload targets
the reader limit. A receipt contains additional data and has its own size budget.

Each row uses three fresh processes. Each process prepares its inputs and warms
up the selected operation once, then times 40 operations for the real workload
or six for a generated workload. The reported time is the median batch duration
divided by iterations. Parsing reads the JSON string into a BOM object.
Assessment starts from a parsed BOM and snapshot. Capture includes assessment,
receipt construction and JSON serialization. Replay starts from serialized
receipt text and verifies the expected digest while recomputing the report.

Timing excludes build, fixture I/O and setup. GNU Time reports the largest peak
RSS across the three complete Moonrun processes, including runtime overhead,
inputs, setup and warmup. It measures process memory, so rows cannot be added or
subtracted to infer per-operation allocation. Local mode reports timing and
leaves RSS blank. The limits are CI budgets for these inputs and this backend.

The regular test matrix also runs deterministic generated properties. Seeds
and case indexes in `generated_properties_test.mbt` identify the generated
JSON mutations, interval cases and mixed BOMs. A failing generated case can be
turned into a minimal fixed regression test alongside the property suite.
