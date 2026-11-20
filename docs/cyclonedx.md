# Import an existing CycloneDX inventory

`read_cyclonedx` connects existing SBOM producers to the OSV evaluator. It does
not scan source trees or generate a BOM. The accepted header is CycloneDX JSON
1.5 or 1.6. This is a bounded inventory projection, not full schema validation.

```sh
moon run lib/cli -- check-cdx samples/cargo.cdx.json samples/RUSTSEC-2020-0071.json
moon run lib/cli -- check-cdx samples/cargo-fixed.cdx.json samples/RUSTSEC-2020-0071.json
moon run lib/cli -- check-cdx samples/cargo-partial.cdx.json samples/RUSTSEC-2020-0071.json
```

The expected exits are 1, 0 and 3. The last BOM contains a fixed Cargo package
and an unsupported npm component. A successful check of the Cargo package does
not hide the unresolved component. If a known hit and unresolved components
coexist, exit 1 takes precedence and the unresolved list remains in the report.
The fixtures are authored examples, not claimed scans of an application.

## Identity and completeness

The `cyclonedx-cargo-v1` profile resolves a component only when:

- `bom-ref` is nonblank and globally unique; it becomes the installation ID;
- type is `library`, `application` or `framework`;
- `purl` is `pkg:cargo/NAME@VERSION`, without encoding, namespace, qualifiers or
  subpath; the Cargo default repository is crates.io;
- name and version exactly agree with the PURL, version is strict SemVer, and
  `group` is absent. No case folding or spelling correction is applied.

Everything else becomes an unresolved row with its JSON pointer, optional ID
and diagnostic code. Incorrect JSON types, duplicate references and exceeded
budgets reject the input with `InputError`. A corrected input can be read with
the same API; there is no retained parser state.

The adapter accounts for `metadata.component`, top-level `components` and their
nested `components`, including unresolved parents. A missing or empty component
set is incomplete. Maximums are 1,024 total components, 16 component nesting
levels and the common 1 Mi UTF-16 input budget. Components are assessed regardless
of dependency reachability. Services, pedigree/history, tool inventories, graph
edges, composition claims, signatures and embedded vulnerabilities/VEX are not
evaluated. This report is about the listed component set, not certification that
the producer supplied a complete application inventory.

## Library workflow

1. Read with `read_cyclonedx(text, origin=label)`.
2. Call `BomImport::assess(snapshot)` and inspect the outer `BomAssessment`
   `exit_code` and `to_json`; the nested assessment alone is not a completeness
   gate for the BOM.
3. Call `inventory_json` only to feed a fully resolved projection into an
   inventory workflow. It raises `unresolved-components` if any row is unresolved.
4. `source` returns the exact original text. `to_json` includes that source and
   all unresolved rows; unknown metadata and original numeric tokens survive
   even though they are not included in version decisions.

The profile deliberately leaves general Package URL parsing to other tools.
Supporting another ecosystem requires explicit identity and ordering semantics,
not merely changing an ecosystem string.
