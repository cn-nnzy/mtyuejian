# Compare complete BOM assessment receipts

Use `compare_bom_deliveries(before, current)` on captured or verified full BOM
receipts. The CLI verifies both input files before comparing:

```sh
moon run lib/cli -- capture-bom samples/cargo.cdx.json samples/RUSTSEC-2020-0071.json > before.bom.delivery.json
moon run lib/cli -- capture-bom samples/cargo-fixed.cdx.json samples/RUSTSEC-2020-0071.json > current.bom.delivery.json
moon run lib/cli -- changes-bom before.bom.delivery.json current.bom.delivery.json
```

The two captures exit 0; comparison exits 0 for the documented version upgrade.
`BomChanges::to_json` includes receipt digests, absolute before/current gates,
resolved decision entries, identity substitutions, source/profile change flags
and unresolved component changes. `exit_code` means:

- 1: a new known match, even if other evidence is incomplete;
- 3: current evidence is incomplete, previous evidence was removed, a resolved
  installation ID was substituted, or the input profile changed;
- 0: none of those delta conditions. Retained known matches remain visible in
  `current_exit_code`, which must be used for an absolute vulnerability gate.

Resolved rows follow the existing inventory-comparison matching and source rules.
Unresolved rows match by input profile and tagged component ID, or JSON pointer
when the ID is missing. External SPDX document references occupy their own domain.
Pointers are positional; reordering unidentified components may add/remove rows.
The report never merges unknown identities by an inferred package name.

Removing an unresolved row requires review. If a current resolved package reuses
its ID, `identity-resolved` shows that candidate package but still returns 3:
the old unsupported identity cannot prove continuity. A reviewed current receipt
can then become the next baseline. This prevents deleting or relabeling unknown
components from quietly bypassing a delta gate. An unchanged incomplete BOM
also returns 3, even when its known version decisions are negative.

Metadata-only source changes are flagged without changing a complete known
version decision. This is an assessment delta, not a generic SBOM structural
diff, reachability analysis, waiver system or replayable archive. Keep the two
full receipts for their original BOM and advisory evidence. Existing inventory
delivery profiles and comparison output stay unchanged.
