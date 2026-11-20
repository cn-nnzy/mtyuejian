///|
test "JSON pointer escapes every slash and tilde in decoded object keys" {
  let raw = "{\"a//~b~c😀\":false}"
  let spans = Map([])
  read_value(raw, spans~) |> ignore
  let path = "/a~1~1~0b~0c😀"
  guard spans.get(path) is Some((start, end)) else {
    fail("escaped pointer missing")
  }
  assert_eq(raw[start:end].to_owned(), "false")
  try
    read_inventory(
      "{\"schema_version\":1,\"packages\":[],\"a//~b~c😀\":false}",
    )
  catch {
    Invalid(path~, ..) => assert_eq(path, "/a~1~1~0b~0c😀")
  } noraise {
    _ => fail("unknown inventory field accepted")
  }
}

///|
test "source position boundaries and document-end line remain bounded" {
  let lines = source_lines("a\r\nb\rc\n")
  assert_eq(lines, [0, 3, 5, 7])
  assert_eq(source_position(lines, 0), (1, 1))
  assert_eq(source_position(lines, 3), (2, 1))
  assert_eq(source_position(lines, 5), (3, 1))
  assert_eq(source_position(lines, 7), (4, 1))
}

///|
test "source indexing bounds pointer storage without restricting ordinary reads" {
  let raw = "{\"" +
    "k".repeat(5000) +
    "\":[" +
    Array::make(1000, "null").join(",") +
    "]}"
  read_value(raw) |> ignore
  let spans = Map([])
  try read_value(raw, spans~) catch {
    Invalid(code~, ..) => assert_eq(code, "source-index-limit")
  } noraise {
    _ => fail("unbounded pointer index accepted")
  }
  read_value("{\"ok\":true}", spans=Map([])) |> ignore
}
