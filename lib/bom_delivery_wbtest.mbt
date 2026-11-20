///|
test "digest-valid invented BOM gate is rejected by recomputation" {
  let doc = read_advisory(
    "{\"id\":\"x_RECEIPT-1\",\"modified\":\"2026-11-20T00:00:00Z\",\"affected\":[]}",
  )
  let captured = capture_bom(
    Snapshot::new([doc]),
    read_bom(
      "{\"bomFormat\":\"CycloneDX\",\"specVersion\":\"1.6\",\"components\":[]}",
    ),
  )
  guard captured.to_json() is Object(fields) else { fail("expected object") }
  fields["report"] = Json("{}")
  fields["sha256"] = Json(
    bom_delivery_digest(
      captured.result.imported.profile,
      captured.result.imported.raw,
      captured.result.imported.origin,
      captured.snapshot_text,
      "{}",
    ),
  )
  try verify_bom_delivery(Json(fields).stringify()) catch {
    Invalid(code~, ..) => assert_eq(code, "report-mismatch")
  } noraise {
    _ => fail("invented complete report accepted")
  }
}
