///|
test "path budget admits its exact boundary and accounts for pointer escapes" {
  let reader = Reader::{
    text: "",
    units: "".code_units(),
    pos: 0,
    nodes: 0,
    spans: None,
    span_units: 0,
    path_units: 16777216 - 8,
  }
  assert_eq(reader.child_path("", "a/~😀"), "/a~1~0😀")
  assert_eq(reader.path_units, 16777216)
  try reader.child_path("", "x") catch {
    Invalid(code~, ..) => assert_eq(code, "json-work-limit")
  } noraise {
    _ => fail("boundary exceeded")
  }
}

///|
test "work budgeting leaves exact number tokens and normal pointers unchanged" {
  let raw = "{\"a//~b\":[900719925474099312345,false,{\"z\":null}]}"
  let spans = Map([])
  let parsed = read_value(raw, spans~)
  guard parsed is Object(fields) &&
    fields.get("a//~b") is Some(List([Number(token), False, Object(_)])) else {
    fail("AST changed")
  }
  assert_eq(token, "900719925474099312345")
  guard spans.get("/a~1~1~0b/0") is Some((start, end)) else {
    fail("pointer changed")
  }
  assert_eq(raw[start:end].to_owned(), token)
}
