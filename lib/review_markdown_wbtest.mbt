///|
test "review inline code delimiters exceed every source backtick run" {
  for
    value in [
      "", "`", "``x`", "   ", "<img src=x>\n**text**|[x](https://example.invalid)",
    ] {
    let quoted = Json(value).stringify()
    let delimiter = "`".repeat(backtick_run(quoted) + 1)
    assert_eq(review_inline(Json(value)), delimiter + quoted + delimiter)
    assert_true(!review_inline(Json(value)).contains("\n"))
  }
}

///|
test "review writer accepts the exact unit budget and rejects excess without truncation" {
  let writer : ReviewWriter = { output: StringBuilder(), units: 8388607, }
  writer.write("界")
  assert_eq(writer.units, 8388608)
  assert_eq(writer.output.to_string(), "界")
  try writer.write("x") catch {
    Invalid(code~, ..) => assert_eq(code, "review-size-limit")
  } noraise {
    _ => fail("oversized review accepted")
  }
  assert_eq(writer.output.to_string(), "界")
}
