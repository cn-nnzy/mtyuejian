# Assess an SPDX package inventory

`read_spdx` accepts the `SPDX-2.3` JSON package-inventory profile. `read_bom`
selects SPDX or CycloneDX from an unambiguous header. Both return `BomImport`
and share assessment, completeness gating and SARIF export. Existing CycloneDX
output is unchanged. This adds an assessment consumer for existing producers
such as [cogna-dev/sbom](https://mooncakes.io/docs/cogna-dev/sbom), not an SPDX
generator or license analyzer. No direct producer interoperability is claimed.

```sh
moon run lib/cli -- check-bom samples/cargo.spdx.json samples/RUSTSEC-2020-0071.json
moon run lib/cli -- sarif-bom samples/cargo.spdx.json samples/cargo.spdx.json samples/RUSTSEC-2020-0071.json
```

Both commands exit 1 using the real RustSec range and a project-authored package
inventory. `check-bom` also accepts existing CycloneDX fixtures. See
[CycloneDX](cyclonedx.md) for the common strict Cargo PURL profile. This adapter
resolves every listed `packages` entry regardless of graph reachability.
`SPDXID` must be a unique non-document `SPDXRef-` identifier with letters, digits,
`.` or `-`. Missing IDs remain unresolved; malformed or duplicate IDs reject
the input. A package resolves only if its single `purl` external reference has
category `PACKAGE-MANAGER` and matches `name` and `versionInfo`. Multiple PURLs,
missing versions, other ecosystems and identity conflicts remain unresolved.
CPEs and other references are preserved without inferring identity from them.

Every external document reference is unresolved because its inventory has not
been expanded. Missing/empty package lists cannot pass. Limits are 1,024 packages,
64 references per package, 64 external documents and the shared JSON budgets.
Unknown fields, license text, checksums and number tokens survive in the original
source. Partial inventory export raises an error. Known hits still take precedence
over an incomplete gate, retaining every unresolved row.

This is not complete SPDX schema validation: document namespace/creation policy,
file and snippet inventories, relationships, licenses and checksums are not
evaluated. Identity uniqueness is checked for package entries. SPDX 3, tag-value,
RDF/XML, automatic external retrieval and dependency reachability are outside
this profile. `read_bom` refuses competing or absent format headers.

Behavioral reference: [SPDX package information](https://spdx.github.io/spdx-spec/v2.3/package-information/).
