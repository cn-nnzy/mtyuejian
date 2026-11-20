///|
test "a matching pin preserves every inventory verdict and canonical receipt" {
  for version in ["1.0.0", "2.0.0", "not-semver"] {
    let captured = delivery(version)
    let restored = @mtyuejian.verify_delivery(
      captured.to_json().stringify(),
      expected_sha256=captured.digest(),
    )
    assert_eq(restored.to_json().stringify(), captured.to_json().stringify())
    assert_eq(
      restored.assessment().exit_code(),
      captured.assessment().exit_code(),
    )
  }
}

///|
test "a valid replacement receipt fails an independently approved inventory pin" {
  let approved = delivery("1.0.0")
  let replacement = delivery("2.0.0")
  assert_eq(
    @mtyuejian.verify_delivery(replacement.to_json().stringify())
    .assessment()
    .exit_code(),
    0,
  )
  try
    @mtyuejian.verify_delivery(
      replacement.to_json().stringify(),
      expected_sha256=approved.digest(),
    )
  catch {
    @mtyuejian.Invalid(code~, ..) => assert_eq(code, "delivery-pin-mismatch")
  } noraise {
    _ => fail("valid replacement bypassed approved pin")
  }
}

///|
test "BOM pins bind unknown evidence even when replacement is complete" {
  let unknown = bom_delivery(
    bom(component("a", "2.0.0").replace(old="pkg:cargo", new="pkg:npm")),
  )
  let complete = bom_delivery(bom(component("a", "2.0.0")))
  assert_eq(
    @mtyuejian.verify_bom_delivery(
      unknown.to_json().stringify(),
      expected_sha256=unknown.digest(),
    )
    .assessment()
    .exit_code(),
    3,
  )
  try
    @mtyuejian.verify_bom_delivery(
      complete.to_json().stringify(),
      expected_sha256=unknown.digest(),
    )
  catch {
    @mtyuejian.Invalid(code~, ..) => assert_eq(code, "delivery-pin-mismatch")
  } noraise {
    _ => fail("changed BOM bypassed pin")
  }
  assert_eq(
    @mtyuejian.verify_bom_delivery(
      complete.to_json().stringify(),
      expected_sha256=complete.digest(),
    )
    .assessment()
    .exit_code(),
    0,
  )
}

///|
test "invalid pin encodings reject and verification can recover" {
  let captured = delivery("1.0.0")
  for
    pin in [
      "",
      "a".repeat(63),
      "a".repeat(65),
      "A".repeat(64),
      "g".repeat(64),
      " ".repeat(64),
    ] {
    try
      @mtyuejian.verify_delivery(
        captured.to_json().stringify(),
        expected_sha256=pin,
      )
    catch {
      @mtyuejian.Invalid(code~, ..) =>
        assert_eq(code, "invalid-expected-digest")
    } noraise {
      _ => fail("invalid pin accepted")
    }
  }
  assert_eq(
    @mtyuejian.verify_delivery(
      captured.to_json().stringify(),
      expected_sha256=captured.digest(),
    ).digest(),
    captured.digest(),
  )
}

///|
test "pinning does not waive content verification or extend the receipt envelope" {
  let captured = delivery("1.0.0")
  let envelope = captured.to_json()
  guard envelope is Object(fields) else { fail("expected object") }
  fields["report"] = Json("{}")
  try
    @mtyuejian.verify_delivery(
      envelope.stringify(),
      expected_sha256=captured.digest(),
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("pin bypassed recomputation")
  }
  let extended = captured.to_json()
  guard extended is Object(extended_fields) else { fail("expected object") }
  extended_fields["expected_sha256"] = Json(captured.digest())
  try @mtyuejian.verify_delivery(extended.stringify()) catch {
    _ => ()
  } noraise {
    _ => fail("self-supplied approval accepted inside receipt")
  }
}
