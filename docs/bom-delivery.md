# Archive and verify an entire BOM assessment

An unresolved component must survive handoff. `capture_bom(snapshot, imported)`
retains the exact CycloneDX/SPDX source, origin, selected profile, full advisory
snapshot and outer report. It does not use `inventory_json`, which correctly
refuses partial projections. Empty and entirely unsupported BOMs can therefore
be archived and remain incomplete on replay.

```sh
moon run lib/cli -- capture-bom samples/cargo-partial.cdx.json samples/RUSTSEC-2020-0071.json > bom.delivery.json
moon run lib/cli -- verify-bom bom.delivery.json
```

Capture exits 0 after producing the receipt. Verify recomputes the whole report
and exits 3 here; a known match exits 1, a complete negative exits 0, invalid input
exits 2. Original BOM and advisory paths are not needed for verification. The
same commands accept `samples/cargo.spdx.json` and yield a known match.

`verify_bom_delivery` returns an opaque `BomDelivery`. Its `assessment`, `digest`
and `to_json` methods provide a verified outer assessment, integrity identifier
and independent receipt view. The assessment can also export SARIF. This receipt
is distinct from the existing inventory delivery; that profile stays unchanged.

The closed `yuejian-bom-delivery-v1` envelope binds `input_profile`, `bom`, `origin`,
`snapshot`, and `report` with domain-separated, UTF-8 byte-length-framed SHA-256.
Verification checks framing, supported profile, canonical snapshot, and byte-exact
recomputed report. Original BOM whitespace, unknown fields and numeric tokens are
retained. Digest-valid invented reports are rejected. A digest is not a signature
or evidence that a publisher or supplied vulnerability data is trustworthy.

The combined five string payloads have a 1,048,576 UTF-16-unit budget. Oversized
receipts raise a clear diagnostic instead of dropping data; envelope parsing has
the same 8 Mi-unit cap as inventory deliveries. The CLI's 8 MiB file limit also
applies. Failed verification leaves no retained state and emits no partial report.
