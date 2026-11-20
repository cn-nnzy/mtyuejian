///|
fn review_payload(markdown : String) -> String raise {
  let marker = "Copy the JSON block for verified replay. It retains all original source and unsupported metadata.\n\n"
  guard markdown.split_once(marker) is Some((_, block)) else {
    fail("complete receipt absent")
  }
  let lines = block.split("\n").map(line => line.to_owned()).collect()
  assert_true(lines.length() >= 3)
  assert_true(lines[0].has_suffix("json"))
  assert_eq(lines[2], lines[0][:lines[0].length() - 4].to_owned())
  lines[1]
}

///|
test "Markdown review preserves each verdict and the complete inventory receipt" {
  for (version, code) in [("1.0.0", 1), ("2.0.0", 0), ("invalid", 3)] {
    let saved = delivery(version)
    let text = saved.to_markdown()
    assert_true(text.contains("Assessment exit code: " + code.to_string()))
    assert_eq(review_payload(text), saved.to_json().stringify())
    assert_eq(
      @mtyuejian.verify_delivery(
        review_payload(text),
        expected_sha256=saved.digest(),
      )
      .assessment()
      .exit_code(),
      code,
    )
  }
}

///|
test "Markdown includes unresolved-only BOM evidence and source metadata" {
  for
    raw in [
      bom(""),
      spdx(""),
      bom(component("a", "2.0.0").replace(old="pkg:cargo", new="pkg:npm")),
    ] {
    let saved = bom_delivery(raw)
    let text = saved.to_markdown()
    assert_true(text.contains("Assessment exit code: 3"))
    assert_true(text.contains("Unresolved entries: 1"))
    assert_eq(
      @mtyuejian.verify_bom_delivery(review_payload(text)).to_json().stringify(),
      saved.to_json().stringify(),
    )
  }
}

///|
test "source correlation summaries retain separate withdrawn and incomplete results" {
  let withdrawn = alias_doc("x_BETA-1", ["SHARED-1"]).replace(
    old="\"modified\":",
    new="\"withdrawn\":\"2026-11-19T01:00:00Z\",\"modified\":",
  )
  let saved = alias_receipt([alias_doc("x_ALPHA-1", ["SHARED-1"]), withdrawn])
  let text = saved.to_markdown()
  assert_true(text.contains("affected: 1"))
  assert_true(text.contains("withdrawn: 1"))
  assert_true(text.contains("Source group 1"))
  assert_true(text.contains("Shared identifier"))
  assert_true(text.contains("Decision indices: `[0,1]`"))
  assert_eq(
    @mtyuejian.verify_delivery(review_payload(text))
    .assessment()
    .outcomes()
    .length(),
    2,
  )
}

///|
test "untrusted formatting remains complete inside adaptive literal delimiters" {
  let marker = "x```<script>test</script>\n# heading\r\n[link](https://example.invalid/) | 😀"
  let source = alias_doc("x_ALPHA-1", [marker]).replace(
    old="\"affected\":",
    new="\"extra\":900719925474099312345,\"affected\":",
  )
  let saved = @mtyuejian.capture(
    @mtyuejian.Snapshot::new([@mtyuejian.read_advisory(source, origin=marker)]),
    [
      @mtyuejian.Package::new(
        id=marker,
        ecosystem="example",
        name="demo",
        version="1.0.0",
      ),
    ],
  )
  let text = saved.to_markdown()
  let payload = review_payload(text)
  assert_eq(payload, saved.to_json().stringify())
  assert_eq(@mtyuejian.verify_delivery(payload).digest(), saved.digest())
  assert_true(text.contains("````json\n"))
  assert_true(text.contains("\\n# heading"))
}

///|
test "review output is deterministic after verified replay and prior view mutation" {
  let saved = bom_delivery(bom(component("a", "1.0.0")))
  let before = saved.to_json().stringify()
  let text = saved.to_markdown()
  if saved.alias_review() is Object(fields) {
    fields["groups"] = Json::null()
  }
  assert_eq(saved.to_markdown(), text)
  assert_eq(@mtyuejian.verify_bom_delivery(before).to_markdown(), text)
  assert_eq(saved.to_json().stringify(), before)
}
