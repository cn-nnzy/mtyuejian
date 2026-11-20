# Validate an independent SBOM producer

This integration runs **Syft 1.57.2**, not a Yuejian BOM builder. It scans the
project-authored minimal Cargo lock inputs in `samples/producer`, emits unmodified
CycloneDX 1.6 and SPDX 2.3, then uses the ordinary Yuejian CLI to capture, verify,
locate SARIF findings and render reviews. No source rewriting or field filtering
occurs between generation and assessment.

With an installed Syft 1.57.2 executable:

```sh
moon run scripts/syft_interop.mbtx /absolute/path/to/syft
```

On Linux x86-64, the runner can instead download the fixed upstream binary,
verify its release SHA-256 before extraction, and run it:

```sh
moon run scripts/syft_interop.mbtx --fetch-linux
```

The Linux CI job uses this path. Other hosts use the executable argument. See
[Syft releases](https://github.com/anchore/syft/releases/tag/v1.57.2) and its
[installation guide](https://oss.anchore.com/docs/installation/syft/). The binary
and generated outputs stay under `_build`; they are not vendored or published.
The runner disables Syft's update check and scans only the specified fixture
directories. Downloading/installing dependencies needs network access; the actual
cataloging and assessment need no registry, container engine or advisory service.

| Input | Cargo decision | Outer gate | Unresolved rows |
| --- | --- | --- | --- |
| `before/Cargo.lock` → CycloneDX | `time@0.2.22`: affected | 1 | directory subject + lock file component |
| `before/Cargo.lock` → SPDX | `time@0.2.22`: affected | 1 | directory subject package without PURL |
| `fixed/Cargo.lock` → CycloneDX | `time@0.2.23`: not matched | 3 | same two unsupported subjects |
| `fixed/Cargo.lock` → SPDX | `time@0.2.23`: not matched | 3 | same unsupported subject |

This deliberately does **not** produce a green outer verdict for the fixed
input. Syft models source directories and files that do not satisfy the Cargo
identity profile. Yuejian retains these as unresolved rows. A known hit still
takes precedence, without hiding incompleteness. The runner asserts all four
gates, individual decisions, unresolved counts and byte-for-byte retained source,
and writes `manifest.json` only after all checks succeed. Generated receipts,
reports, SARIF, Markdown, producer version and logs remain in the printed folder.

The lock files are minimal, project-authored cataloger inputs, not a claimed
complete Cargo resolution or a scanned production application. The real RustSec
fixture supplies version-range evidence only. Passing this integration establishes
these four cases for this producer/version and profile; it does not establish
general Syft, SPDX, CycloneDX or hosted viewer compatibility. Syft-generated UUIDs
and timestamps vary; Yuejian preserves them rather than normalizing the source.

An attempted `cogna-dev/sbom@0.1.1` registry integration on MoonBit stable
0.1.20261119 was blocked because that release uses `moon.mod.json`, which this
toolchain refuses. No direct runtime compatibility is claimed for that package;
its sources or registry metadata have not been patched in this project.
