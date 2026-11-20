# Self-contained assessment delivery

`capture(snapshot, packages)` creates a delivery containing the canonical
inventory, original advisory snapshot, recomputed assessment, and SHA-256 digest.
`verify_delivery(text)` checks the digest, reads the inputs again, and recomputes
the report. Its opaque return value exposes `assessment()`, `digest()` and
`to_json()`; returned JSON cannot mutate the saved state.

For the real sample:

```sh
moon run lib/cli -- capture samples/installed.json samples/RUSTSEC-2020-0071.json > assessment.delivery.json
moon run lib/cli -- verify assessment.delivery.json
```

Save stdout as UTF-8 when using a shell that defaults to a different encoding.
Capture exits 0 when it produces an artifact; it does not gate the assessment.
Verification prints the rebuilt report and returns its original gate: 1 for this
sample. The clean fixed-version sample returns 0, and missing evidence returns 3.
Malformed or changed deliveries return a structured error and exit 2.

The whole file is sufficient to reproduce a supplied assessment without its
original file paths or network access. It records source labels rather than
opening them. Run `moon run scripts/e2e.mbtx wasm` for an automated workflow that
also checks tampering, source-free verification, and recovery after an error.

## Encoding and trust boundary

The closed `yuejian-delivery-v1` envelope has schema version 1 and string fields
`inventory`, `snapshot`, `report`, and `sha256`. The three payloads are canonical
serializations emitted by this version's API. Advisory text inside the snapshot
remains exactly as supplied. The combined payload is limited to 1,048,576 UTF-16
code units; the escaped envelope is limited to 8,388,608 code units. This bound
ensures that capture output can be read back even when escaping expands it.

The digest is lowercase hexadecimal SHA-256 over UTF-8 bytes of:

```text
yuejian-delivery-v1\n
<inventory UTF-8 byte length>:<inventory>
<snapshot UTF-8 byte length>:<snapshot>
<report UTF-8 byte length>:<report>
```

Only the domain line contains a newline; no separators are inserted between the
three length-prefixed payloads. Lengths are plain decimal ASCII without leading
zeros. Byte lengths, rather than character counts, make Unicode framing explicit.

Content checks detect corruption and input/result substitution. A digest-valid
invented report still fails recomputation. An attacker can construct a different,
self-consistent delivery and calculate its digest, so this format does not
authenticate a publisher or establish advisory completeness. Store or transmit
the digest through a trusted channel if an external binding is required.

The format binds assessment-v1 semantics through its profile. Future changes to
those semantics must use a new profile rather than silently reinterpret an old
delivery. It is not a generic JSON signing or canonicalization standard.
