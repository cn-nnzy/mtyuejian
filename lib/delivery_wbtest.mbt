///|
test "digest-valid invented reports are rejected" {
  let raw = "{\"id\":\"x_A\",\"modified\":\"2026-11-19T00:00:00Z\",\"affected\":[{\"package\":{\"ecosystem\":\"example\",\"name\":\"demo\"},\"versions\":[\"1.0.0\"]}]}"
  let saved = capture(Snapshot::new([read_advisory(raw)]), [
    Package::new(id="a", ecosystem="example", name="demo", version="1.0.0"),
  ])
  let forged = saved.to_json()
  guard forged is Object(fields) else { fail("missing envelope") }
  fields["report"] = Json("{}")
  fields["sha256"] = Json(
    delivery_digest(saved.inventory_text, saved.snapshot_text, "{}"),
  )
  try verify_delivery(forged.stringify()) catch {
    Invalid(code~, ..) => assert_eq(code, "report-mismatch")
  } noraise {
    _ => fail("invented report accepted")
  }
}

///|
test "digest framing separates fields and hashes UTF-8" {
  assert_not_eq(delivery_digest("ab", "c", ""), delivery_digest("a", "bc", ""))
  assert_not_eq(
    delivery_digest("月", "鉴", ""),
    delivery_digest("月鉴", "", ""),
  )
  assert_eq(delivery_digest("", "", "").length(), 64)
}
