///|
test "unnamed producer package nodes remain unresolved and replayable in both BOM formats" {
  let unnamed = "{\"type\":\"library\",\"bom-ref\":\"unknown\",\"name\":\"\",\"properties\":[{\"name\":\"producer:PkgID\",\"value\":\"demo@2.0.0\"}]}"
  let inputs = [
    bom(component("known", "2.0.0") + "," + unnamed, version="1.7"),
    bom(component("known", "2.0.0") + "," + unnamed, version="1.6"),
    spdx(
      spdx_package("SPDXRef-known", "2.0.0") +
      ",{\"SPDXID\":\"SPDXRef-unknown\",\"name\":\"\"}",
    ),
  ]
  for raw in inputs {
    let imported = @mtyuejian.read_bom(raw)
    assert_eq(imported.source(), raw)
    let result = imported.assess(cargo_snapshot())
    assert_eq(result.exit_code(), 3)
    guard result.to_json()
      is {
        "import": {
          "packages": Array([_]),
          "unresolved": Array([{ "code": "missing-purl", .. }]),
          ..
        },
        ..
      } else {
      fail("Unidentified node was dropped or guessed")
    }
    try imported.inventory_json() catch {
      _ => ()
    } noraise {
      _ => fail("Unidentified node yielded a complete inventory")
    }
    let receipt = @mtyuejian.capture_bom(cargo_snapshot(), imported)
    let saved = receipt.to_json().stringify()
    assert_eq(
      @mtyuejian.verify_bom_delivery(saved).to_json().stringify(),
      saved,
    )
  }
}

///|
test "empty component names cannot be reconstructed from PURLs and wrong JSON types still reject" {
  for
    raw in [
      bom(
        component("a", "2.0.0").replace(
          old="\"name\":\"demo\"",
          new="\"name\":\"\"",
        ),
        version="1.7",
      ),
      spdx(
        spdx_package("SPDXRef-a", "2.0.0").replace(
          old="\"name\":\"demo\"",
          new="\"name\":\"\"",
        ),
      ),
    ] {
    let result = @mtyuejian.read_bom(raw).assess(cargo_snapshot())
    assert_eq(result.exit_code(), 3)
    guard result.to_json()
      is {
        "import": {
          "packages": Array([]),
          "unresolved": Array([{ "code": "component-name-conflict", .. }]),
          ..
        },
        ..
      } else {
      fail("A missing name was inferred")
    }
    let malformed = raw.replace(old="\"name\":\"\"", new="\"name\":null")
    try @mtyuejian.read_bom(malformed) catch {
      @mtyuejian.Invalid(code~, ..) => assert_eq(code, "expected-string")
    } noraise {
      _ => fail("An invalid name type was accepted")
    }
    assert_eq(@mtyuejian.read_bom(raw).assess(cargo_snapshot()).exit_code(), 3)
  }
}
