# Release and adoption contract for 0.1.0

0.1.0 is currently a source/release candidate. Preparation does not publish a
Mooncakes module. GitHub push authorization and registry credentials are distinct.
Publication is deferred while the [maturity gates](maturity.md) are evaluated;
candidate verification does not authorize upload.

## Candidate corrections, 2026-11-27

- Direct API package fields and origin labels now reject unpaired UTF-16
  surrogates before serialization, with `invalid-unicode` and a field pointer.
  Previously these inputs could enter objects despite the JSON reader rejecting
  them, allowing later encoders to replace or reject their content.
- `inventory_json` and assessments now reject inventories whose canonical JSON
  exceeds the paired reader's 1,048,576 UTF-16 unit budget, including escapes.
  Individually valid fields do not imply a serializable aggregate. The error is
  `document-limit`; split large inventories into separately reviewed assessments.

These corrections retain public signatures and the bytes and behavior of valid
historical receipts. They tighten rejection at library input boundaries.

## Public API and evidence compatibility

The frozen candidate interface is [release/api-0.1.0.mbti](../release/api-0.1.0.mbti),
copied exactly from `moon info`. Release preparation refuses interface drift.
Patch releases preserve these signatures for valid inputs. New capabilities are
added through explicit APIs; breaking API changes require a new minor version
while below 1.0. Corrections involving malformed/unsafe inputs may reject such
inputs more strictly and must be documented in release notes.

Default evaluation remains `version-evidence-v1`, snapshot schema 1. Explicit
crates.io evaluation uses `crates-io-semver-v1`, snapshot schema 2. Receipt v1
envelopes bind the complete selected snapshot. A semantic change requires a new
named profile, not silently different recomputation of an old profile. Unknown
profile/schema combinations are rejected. Comparisons report profile changes
separately and retain the conservative gate. Existing committed golden receipts
and public-project archives test valid historical replay.

## Read-only candidate verification

After reviewing and committing all release source, run:

```sh
moon run scripts/registry_smoke.mbtx --archive
moon run scripts/release_check.mbtx
```

The first command needs Python 3 to extract the package. It copies the standalone
consumer template into a fresh directory and uses an explicit local workspace to
the extracted source archive. It checks all supported targets and **runs** Wasm,
Wasm-GC and JavaScript. This is an archive-adoption test, not registry verification.

The second command requires a clean checkout, checks the frozen public interface,
format, generated interfaces and strict compilation, packages the module, and
writes `_build/publish/release-candidate.json` with the source commit, archive
SHA-256 and API SHA-256. It performs no login, upload, tag or GitHub release.
The manifest is an unsigned review record, not publisher authentication.

## Publication and actual registry consumption

Publication requires the owner's explicit approval of the prepared candidate,
plus a Mooncakes login authorized for `cn-nnzy`. Do not use a saved account for
another namespace or change the module name to bypass permission checks. Use a
dedicated MOON_HOME for authentication when the default account belongs to other
work. Credentials/tokens must never enter source, logs or release artifacts.

After approval and correct login:

```sh
moon whoami
moon publish --dry-run
moon publish
moon run scripts/registry_smoke.mbtx --registry
```

The registry check first requires live metadata for the exact published version.
It creates a fresh consumer with **no moon.work override**, checks dependency
resolution and the installed registry API against the frozen baseline, then runs
the same three targets. A missing version or mismatched API fails the check;
there is no fallback to local source. Only after this passes may README/package
notes say the version is published. The CI workflow's manual `verify_registry`
option repeats this verification after a release; ordinary pushes use archive mode.

The consumer template is [examples/registry-consumer](../examples/registry-consumer).
It verifies legacy behavior, explicit crates.io evaluation, profile round trips,
receipt pins, coverage and Markdown through the public library API.
