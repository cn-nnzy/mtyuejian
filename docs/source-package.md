# Verify the source package

`moon package` creates a local MoonBit source archive; it does not publish it.
The archive must include the license, dependency/source notices, public interface,
tests, examples and sample data. A successful build from a checkout alone does
not establish that these files survive packaging.

From the repository root, with MoonBit stable and Python 3 available:

```sh
moon run scripts/package_smoke.mbtx
```

If Python is not named `python` on the host, pass its executable path as the
single argument. The script uses Python's standard `zipfile` CLI only to unpack
the archive; all workflow logic is MoonBit.

The smoke check creates `cn-nnzy-mtyuejian-0.1.0.zip` in `_build/publish`, extracts
it into a fresh `_build/yuejian-package-…` directory and checks:

1. Build outputs, Git metadata and dependency caches were not packaged.
2. License/source notices and consuming examples are present.
3. Formatting and regenerated public interfaces agree with the packaged source.
4. All supported backends pass strict compilation checks.
5. Wasm unit tests execute from the extracted source.
6. The independent consuming module resolves the extracted library through its
   relative workspace, and the packaged CLI assesses the real RustSec fixture.

Fresh extraction avoids using the checkout's compiled outputs. Dependencies
still come from the normal MoonBit cache/registry; this is not a hermetic-build
claim. The test retains its extracted directory for inspection and performs no
recursive deletion. This check does not publish a Mooncakes version, create a
release, or install an executable globally. Native execution is checked separately
in the repository's three operating-system CI jobs.
