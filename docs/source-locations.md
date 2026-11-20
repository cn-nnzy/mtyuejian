# Bind SARIF regions to the actual JSON source

The optional source workflow gives report viewers real version-field coordinates
without searching message text or guessing line 1. Inventory export requires the
exact assessed installation set, identities and versions; order, JSON escaping
and whitespace may differ. A mismatching source is rejected before any SARIF is
printed. BOM export uses its exact retained source, including unresolved rows.
Indexing also caps aggregate JSON Pointer storage at 4,194,304 UTF-16 units;
excessively complex metadata is rejected with `source-index-limit`. Artifact-only
export remains available without omitting that metadata from the saved source.

```sh
moon run lib/cli -- capture samples/installed.json samples/RUSTSEC-2020-0071.json > delivery.json
moon run lib/cli -- sarif-located delivery.json samples/installed.json samples/installed.json > located.sarif
moon run lib/cli -- sarif-bom-located samples/cargo.spdx.json samples/cargo.spdx.json samples/RUSTSEC-2020-0071.json > spdx.sarif
```

Capture exits 0; both exports exit 1. Substituting `samples/fixed.json` as the
location source for the two-package delivery raises a diagnostic and exits 2.
`sarif-bom-located` also accepts CycloneDX, including the partial sample, which
retains its incomplete gate 3. Ordinary unlocated export commands remain available.

Library calls are `assessment.to_sarif(inventory_uri=uri, inventory_source=text)`
and `bom_assessment.to_sarif(bom_uri=uri, locate=true)`. Generated interfaces contain
the exact signatures. URI restrictions from [SARIF](sarif.md) still apply. The
URI is caller-provided artifact metadata; the core does not open that path. The
file CLI reads the supplied source and binds its complete package set to the
verified assessment before deriving coordinates.

The private bounded JSON reader records value spans by decoded JSON Pointer.
Known package results point at the original `version` or SPDX `versionInfo`
string token, including quotes. Unresolved nodes point at their actual component,
package or external-document object. A missing field has no region to invent;
the result keeps an artifact-only location. Unscoped advisory entries still have
no fabricated inventory location. Unknown BOM fields remain in the retained text.

SARIF columns are explicitly `utf16CodeUnits`; surrogate pairs occupy two units,
tabs one. Lines count CRLF as one break, as well as LF and bare CR, recorded in
`newlineSequences`. JSON escape sequences count their actual source width;
an escaped `\n` is not a physical line break. Regions use one-based start/end
lines and columns with an exclusive end. The exact indexed text is retained as
`run.properties["yuejian/location_source"]`. No byte offsets or visual tab widths
are claimed. Fingerprints, assessment gates and archived receipt formats are
unaffected by adding regions.

Tests cover Unicode, raw escapes, line endings, reordered input, unsupported
nodes, source mismatch, recovery, and repeated slash/tilde pointer escaping.
All five end-to-end SARIF artifacts, including located SPDX and partial BOM
reports, are independently checked against the pinned OASIS schema in CI.
Domain tests check coordinates and the independent validator checks format;
no hosted upload or annotation workflow has been tested or claimed.
