# Reproduce a complete public-project review

This workflow uses full upstream source checkouts and unmodified Cargo lock
files from two real applications. It assesses every listed lock package, including
development and target-specific entries. It does not resolve Cargo features,
build the applications, or claim these are deployed/runtime inventories.

After `moon update`, run from the Yuejian repository root:

```sh
# Linux x86-64: download and verify the fixed Syft 1.57.2 binary.
moon run scripts/real_projects.mbtx --fetch-linux

# Other hosts: provide an installed Syft 1.57.2 executable.
moon run scripts/real_projects.mbtx /absolute/path/to/syft
```

Git and initial network access are needed to acquire the four pinned source
commits. No upstream project code, package installer or build script is executed.
The Linux CI job runs this complete workflow. `native` can be added as the final
argument on a host with the required C toolchain; the default CLI target is Wasm.

## Pinned inputs and measured results

The exact peeled commits and SHA-256 of each lock file, root manifest and MIT
license file are in [samples/real-projects.json](../samples/real-projects.json).
Sources are fetched by commit, not a mutable branch/tag. Checkouts disable Git's
automatic newline conversion and reject primary-file digest mismatches.

| Historical application release | Lock packages | Resolved packages | Unresolved entries | Gate |
| --- | ---: | ---: | ---: | ---: |
| exa 0.10.0 | 43 | 40 | 4 | 1 |
| exa 0.10.1 | 45 | 42 | 4 | 1 |
| zoxide 0.7.9 | 98 | 95 | 4 | 1 |
| zoxide 0.9.0 | 106 | 103 | 4 | 3 |

Both CycloneDX 1.6 and SPDX 2.3 produce these counts. Each row's unresolved total
includes three package identity issues and one directory subject, so
`resolved + unresolved = lock packages + 1`. The runner additionally compares
the complete name/version multisets in Syft JSON and both BOM formats. No package
is dropped merely because the strict Cargo profile cannot resolve its PURL.
Percent-encoded build metadata, missing PURLs and conflicting case remain
visible in the coverage diagnostics and original BOM text.

The producer selects the Rust lock cataloger with its file-cataloger tag disabled;
it still retains the directory subject. This is an explicit producer configuration
for package-inventory review, not filtering of generated BOMs. Every generated
BOM is fed unchanged to Yuejian and checked for byte-for-byte receipt retention.

Two committed real RustSec records are deliberately selected. `RUSTSEC-2021-0139`
is an **informational maintenance advisory** for ansi_term: both exa versions
retain a matching version. `RUSTSEC-2021-0145` describes atty with Windows and
allocator conditions; version evidence matches zoxide 0.7.9, while zoxide 0.9.0
has no matching package. Conditions/exploitability are not evaluated. The later
zoxide review still exits 3 because missing advisory coverage and unresolved
identities remain. These historical examples do not describe current upstream
security or a complete advisory database.

## Artifacts, comparisons and offline replay

Each run creates a fresh `_build/yuejian-real-projects-…` directory containing:

- Four full upstream source checkouts, retaining original MIT license notices.
- Eight original BOMs, eight SHA-256 receipts, recomputed reports, coverage views,
  located SARIF files and Markdown reviews; four original Syft JSON catalogs.
- Four comparisons between the actual application releases, with pinned baseline
  receipt digests. Every delta remains 3 where incomplete evidence needs review;
  this is separate from the current absolute gate.
- Source configuration, advisory copies, attribution/license files and a manifest
  with artifact byte digests, source commits and measured coverage counts.

The success manifest is written only after exact replay, rejection of altered
artifact digests and escaping artifact/receipt paths, and successful recovery
with the original inputs. Generation does not replace existing review folders.

With Yuejian dependencies already installed, replay from the repository root:

```sh
moon run scripts/real_projects.mbtx --replay REVIEW_DIRECTORY
```

Replace `REVIEW_DIRECTORY` with the printed path. Replay needs neither Git, Syft,
network advisory lookup nor the source checkouts; receipts contain complete BOM
and advisory inputs. Reports and coverage must reproduce exactly, including the
four comparisons. Paths are confined to the review directory after realpath
resolution; replay rejects artifacts above 16 MiB. Moving the kit preserves replay
because retained origin labels are provenance, not required filesystem paths.

Syft timestamps/UUIDs can differ between new scans; generated receipts are not
claimed identical across fresh generation runs. Replaying one archived kit is
deterministic. The manifest and self-recorded pins are integrity evidence, not
signatures or approval; real approval requires independently trusted pins.
