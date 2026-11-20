# Pin the exact receipt or comparison baseline

Receipt verification proves internal consistency. An independently approved
SHA-256 also identifies which receipt the caller intended to use. Supply it with
`verify_delivery(text, expected_sha256=pin)` or
`verify_bom_delivery(text, expected_sha256=pin)`. A valid replacement with different
inputs, metadata or source labels is rejected as `delivery-pin-mismatch`, even
when its recomputed assessment would be complete. A matching pin preserves the
original verdict and canonical envelope.

The file commands accept these forms:

```text
moon run lib/cli -- verify --expected-sha256 SHA256 DELIVERY.json
moon run lib/cli -- verify-bom --expected-sha256 SHA256 BOM.delivery.json
moon run lib/cli -- changes --baseline-sha256 SHA256 BEFORE.json CURRENT.json
moon run lib/cli -- changes-bom --baseline-sha256 SHA256 BEFORE.json CURRENT.json
```

Replace `SHA256` with the 64 lowercase hexadecimal characters approved for that
receipt. Pinning a comparison applies to the before receipt; the current receipt
is still independently verified. A mismatch or malformed pin exits 2 before any
partial output. Successful verification/comparison retains its usual 0/1/3 gate.
The complete acceptance, replacement-rejection and recovery workflow is runnable
with `moon run scripts/e2e.mbtx wasm`; the separate consumer example exercises the
public API.

Store the approved digest separately, for example in a reviewed CI configuration.
Reading a digest from the same untrusted receipt and passing it back does not
establish approval. The wire profiles remain closed and unchanged: a pin is an
external parameter, not an editable approval field inside the artifact.

A pin authenticates neither a person nor vulnerability data. It has no signer,
expiration or revocation protocol. An attacker who can replace both the artifact
and the independently trusted pin is outside this check's boundary. Existing
unpinned calls continue to perform full recomputation without assuming approval.
