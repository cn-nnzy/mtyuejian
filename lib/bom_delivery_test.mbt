///|
fn bom_delivery(raw : String) -> @mtyuejian.BomDelivery raise {
  @mtyuejian.capture_bom(
    cargo_snapshot(),
    @mtyuejian.read_bom(raw, origin="fixture"),
  )
}

///|
test "BOM deliveries preserve resolved partial empty and SPDX inputs" {
  for
    raw in [
      bom(component("a", "1.0.0")),
      bom(component("a", "2.0.0")),
      bom(""),
      bom(component("a", "2.0.0").replace(old="pkg:cargo", new="pkg:npm")),
      spdx(spdx_package("SPDXRef-a", "1.0.0")),
      spdx(""),
    ] {
    let captured = bom_delivery(raw)
    let restored = @mtyuejian.verify_bom_delivery(
      captured.to_json().stringify(),
    )
    assert_eq(restored.digest(), captured.digest())
    assert_eq(restored.to_json().stringify(), captured.to_json().stringify())
    assert_eq(
      restored.assessment().to_json().stringify(),
      captured.assessment().to_json().stringify(),
    )
    guard restored.assessment().to_json()
      is { "import": { "source": String(source), .. }, .. } else {
      fail("raw BOM missing")
    }
    assert_eq(source, raw)
  }
}

///|
test "every BOM receipt payload is bound to the digest" {
  let saved = bom_delivery(bom(component("a", "1.0.0")))
  for key in ["input_profile", "bom", "origin", "snapshot", "report", "sha256"] {
    let envelope = saved.to_json()
    guard envelope is Object(fields) && fields[key] is String(value) else {
      fail("missing payload")
    }
    fields[key] = Json(value + " ")
    try @mtyuejian.verify_bom_delivery(envelope.stringify()) catch {
      _ => ()
    } noraise {
      _ => fail("tampering accepted: " + key)
    }
  }
}

///|
test "BOM receipt views are independent and rejection does not poison replay" {
  let saved = bom_delivery(bom("{}"))
  let text = saved.to_json().stringify()
  if saved.to_json() is Object(fields) {
    fields["report"] = Json("{}")
  }
  assert_eq(saved.to_json().stringify(), text)
  try @mtyuejian.verify_bom_delivery(text + " false") catch {
    _ => ()
  } noraise {
    _ => fail("trailing content accepted")
  }
  assert_eq(@mtyuejian.verify_bom_delivery(text).assessment().exit_code(), 3)
}

///|
test "BOM receipt framing preserves Unicode source and origin labels" {
  let raw = "\n " +
    bom(component("a", "1.0.0")).replace(
      old="\"components\":",
      new="\"metadata\":{\"note\":\"审查😀\",\"big\":900719925474099312345},\"components\":",
    )
  let first = @mtyuejian.capture_bom(
    cargo_snapshot(),
    @mtyuejian.read_bom(raw, origin="来源😀"),
  )
  let second = @mtyuejian.capture_bom(
    cargo_snapshot(),
    @mtyuejian.read_bom(raw, origin="来源"),
  )
  assert_true(first.digest() != second.digest())
  assert_eq(
    @mtyuejian.verify_bom_delivery(first.to_json().stringify())
    .to_json()
    .stringify(),
    first.to_json().stringify(),
  )
}

///|
test "BOM delivery size budget rejects large sources without truncation" {
  let small = bom("{}").replace(
    old="\"components\":",
    new="\"padding\":\"" + "x".repeat(300000) + "\",\"components\":",
  )
  let saved = bom_delivery(small)
  assert_eq(
    @mtyuejian.verify_bom_delivery(saved.to_json().stringify()).digest(),
    saved.digest(),
  )
  let large = bom("{}").replace(
    old="\"components\":",
    new="\"padding\":\"" + "x".repeat(600000) + "\",\"components\":",
  )
  try bom_delivery(large) catch {
    _ => ()
  } noraise {
    _ => fail("oversized source silently truncated")
  }
}

///|
test "BOM receipt envelope is closed and distinct from inventory delivery" {
  let envelope = bom_delivery(bom("")).to_json()
  guard envelope is Object(fields) else { fail("expected envelope") }
  fields["extra"] = Json(false)
  try @mtyuejian.verify_bom_delivery(envelope.stringify()) catch {
    _ => ()
  } noraise {
    _ => fail("unknown envelope field accepted")
  }
  try
    @mtyuejian.verify_bom_delivery(delivery("1.0.0").to_json().stringify())
  catch {
    _ => ()
  } noraise {
    _ => fail("inventory receipt accepted as BOM")
  }
}
