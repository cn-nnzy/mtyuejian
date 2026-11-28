# Compare the package scope of two SBOMs

Use `compare-bom-scope` when two producers describe the same source or build
and you need to see which Cargo package instances each one reports. Pass the
original CycloneDX JSON or SPDX 2.3 JSON files in either order.

```sh
moon run lib/cli -- compare-bom-scope samples/cargo.cdx.json samples/cargo.spdx.json
moon run lib/cli -- compare-bom-scope samples/cargo.cdx.json samples/cargo-fixed.cdx.json
```

The first example reports one shared `time@0.2.22` instance and exits 0. The
second reports one instance of `time@0.2.22` on the left and one of
`time@0.2.23` on the right, and exits 3.

- **0** means exact resolved identity counts agree and both imports have zero unresolved entries.
- **3** means at least one count differs or an import has unresolved entries.
- **2** means an input failed to load or validate, or the command syntax was invalid.

The scope gate applies only to the two supplied inventories. Advisory assessment
and receipt comparisons use their own commands and gates.

The `cargo-bom-scope-v1` view groups by exact ecosystem, name and version
spelling. A group with two left instances and one right instance contributes
one shared instance and one left-only instance. Its report retains all three
source-local IDs, leaving it to a reviewer to decide whether any two IDs refer
to the same physical instance. Matching counts can include repeated coordinates.
Groups and IDs use deterministic text ordering. Unresolved nodes remain in the
side that supplied them, together with their original pointers and codes.

Each side includes the source SHA-256 of the original UTF-8 bytes. Keep the two
BOMs alongside the JSON report to reproduce a comparison. Library users can pass
two `BomImport` values to `compare_bom_scope(left, right)` and call
`exit_code()` or `to_json()`. The comparison uses the same bounded Cargo
projection as the existing BOM adapters.

The [Syft and Trivy workflow](trivy-interop.md) generates and replays eight scope
reports on four pinned historical source revisions. Those reports compare the
resolved Cargo projections. The companion catalog scope files account for
producer differences upstream of the BOM adapters.
