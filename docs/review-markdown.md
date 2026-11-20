# Share a readable review with its complete receipt

`Delivery::to_markdown` and `BomDelivery::to_markdown` produce a human-readable
decision review followed by the full canonical JSON receipt. The report includes
the original assessment gate, every source decision/evidence pointer, unresolved
BOM entries and declared-identifier source groups. Counts remain package/source
decision counts. It does not collapse them into a count of unique CVEs.

```sh
moon run lib/cli -- capture samples/installed.json samples/RUSTSEC-2020-0071.json samples/GHSA-wcg3-cvx6-7396.json > linked.delivery.json
moon run lib/cli -- review linked.delivery.json > review.md
moon run lib/cli -- capture-bom samples/cargo-partial.cdx.json samples/RUSTSEC-2020-0071.json > partial.delivery.json
moon run lib/cli -- review-bom partial.delivery.json > partial-review.md
```

All four artifact-creation commands exit 0. The first Markdown review explicitly
shows assessment exit 1; the partial BOM shows 3. `review` reports generation
success, not an absolute vulnerability gate. Use `verify` / `verify-bom` when CI
must return the assessment's 0/1/3 exit code. Both review commands also accept
`--expected-sha256 SHA256 FILE` to enforce an independently approved receipt pin.
Malformed input or a pin mismatch exits 2 without printing partial Markdown.

Every source value is displayed as JSON inside an adaptive backtick code span.
JSON control characters remain visible as escapes, and a value cannot close its own
delimiter to create Markdown links, headings or raw HTML. The full JSON block
uses a fence longer than every backtick run in the serialized receipt. Original
source text, large-number tokens, whitespace and unsupported metadata remain
inside that complete receipt; the readable sections are a review aid.

Copy the JSON block under `Complete receipt` into a file for normal verification
and replay. The receipt's framed payloads and digest are unchanged; outer JSON
whitespace is canonicalized. Tests verify exact receipt round trips through the
Markdown block. Output is capped at 8,388,608 UTF-16 units and raises an explicit
diagnostic rather than truncating or dropping evidence. This is not a general
Markdown parser or an HTML sanitization API for arbitrary documents.

## Independent rendering check

```sh
moon run scripts/e2e.mbtx wasm
python -m pip install commonmark==0.9.1
moon run scripts/review_render.mbtx
```

The end-to-end run writes three reviews under `_build`: a real two-source
assessment, a partial BOM, and deliberately untrusted formatting in an
installation ID. The check invokes the pinned independent `cmark` renderer,
verifies one complete receipt block in each output and checks that supplied
HTML/link syntax remains literal. It also writes `.md.html` files for inspection.
The renderer is a validation dependency only, not a library or runtime dependency.
An explicit renderer executable can be passed as the script's first argument.
Linux CI runs this check alongside the independent SARIF checks. Renderer behavior
beyond that tested implementation is not claimed.

Code delimiters follow [CommonMark code-span](https://spec.commonmark.org/0.31.2/#code-spans)
and [fenced-block](https://spec.commonmark.org/0.31.2/#fenced-code-blocks) rules.
