///|
fn repeated_metadata(count : Int32) -> String {
  bom(component("a", "2.0.0")).replace(
    old="\"components\":",
    new="\"extension\":{\"" +
      "x".repeat(5000) +
      "\":[" +
      Array::make(count, "null").join(",") +
      "]},\"components\":",
  )
}

///|
test "long repeated metadata paths are bounded before excessive construction" {
  let raw = repeated_metadata(4000)
  assert_true(raw.length() < 1048576)
  try @mtyuejian.read_bom(raw) catch {
    @mtyuejian.Invalid(code~, path~, ..) => {
      assert_eq(code, "json-work-limit")
      assert_eq(path, "")
    }
  } noraise {
    _ => fail("path amplification accepted")
  }
  assert_eq(
    @mtyuejian.read_bom(bom(component("a", "2.0.0")))
    .assess(cargo_snapshot())
    .exit_code(),
    0,
  )
}

///|
test "bounded metadata remains lossless through ordinary reading and receipts" {
  let raw = repeated_metadata(1000)
  let imported = @mtyuejian.read_bom(raw)
  assert_eq(imported.source(), raw)
  let captured = @mtyuejian.capture_bom(cargo_snapshot(), imported)
  let restored = @mtyuejian.verify_bom_delivery(captured.to_json().stringify())
  assert_eq(restored.to_json().stringify(), captured.to_json().stringify())
  assert_eq(restored.assessment().exit_code(), 0)
}
