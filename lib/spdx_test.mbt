///|
fn spdx(items : String) -> String {
  "{\"spdxVersion\":\"SPDX-2.3\",\"SPDXID\":\"SPDXRef-DOCUMENT\",\"packages\":[" +
  items +
  "]}"
}

///|
fn spdx_package(id : String, version : String) -> String {
  "{\"SPDXID\":\"" +
  id +
  "\",\"name\":\"demo\",\"versionInfo\":\"" +
  version +
  "\",\"externalRefs\":[{\"referenceCategory\":\"PACKAGE-MANAGER\",\"referenceType\":\"purl\",\"referenceLocator\":\"pkg:cargo/demo@" +
  version +
  "\"}]}"
}

///|
test "SPDX and CycloneDX resolve the same exact Cargo version evidence" {
  for version in ["1.0.0", "2.0.0"] {
    let a = @mtyuejian.read_spdx(spdx(spdx_package("SPDXRef-a", version)))
    let b = @mtyuejian.read_cyclonedx(bom(component("SPDXRef-a", version)))
    assert_eq(a.inventory_json().stringify(), b.inventory_json().stringify())
    assert_eq(
      a.assess(cargo_snapshot()).exit_code(),
      b.assess(cargo_snapshot()).exit_code(),
    )
  }
}

///|
test "SPDX preserves unsupported and conflicting package evidence" {
  let base = spdx_package("SPDXRef-a", "2.0.0")
  for
    item in [
      base.replace(old="pkg:cargo", new="pkg:npm"),
      base.replace(old="\"name\":\"demo\"", new="\"name\":\"other\""),
      base.replace(
        old="\"versionInfo\":\"2.0.0\"",
        new="\"versionInfo\":\"3.0.0\"",
      ),
      "{\"SPDXID\":\"SPDXRef-a\",\"name\":\"demo\"}",
      "{}",
    ] {
    let imported = @mtyuejian.read_spdx(spdx(item))
    assert_eq(imported.assess(cargo_snapshot()).exit_code(), 3)
    try imported.inventory_json() catch {
      _ => ()
    } noraise {
      _ => fail("partial inventory escaped")
    }
  }
}

///|
test "multiple PURLs and incorrect categories cannot choose an identity" {
  let base = spdx_package("SPDXRef-a", "1.0.0")
  for
    item in [
      base.replace(old="PACKAGE-MANAGER", new="SECURITY"),
      base.replace(
        old="\"externalRefs\":[",
        new="\"externalRefs\":[{\"referenceCategory\":\"PACKAGE-MANAGER\",\"referenceType\":\"purl\",\"referenceLocator\":\"pkg:cargo/other@1.0.0\"},",
      ),
    ] {
    assert_eq(
      @mtyuejian.read_spdx(spdx(item)).assess(cargo_snapshot()).exit_code(),
      3,
    )
  }
}

///|
test "external SPDX inventories prevent complete negative reports" {
  let raw = spdx(spdx_package("SPDXRef-a", "2.0.0")).replace(
    old="\"packages\":",
    new="\"externalDocumentRefs\":[{\"externalDocumentId\":\"DocumentRef-other\"}],\"packages\":",
  )
  let imported = @mtyuejian.read_spdx(raw)
  assert_eq(imported.assess(cargo_snapshot()).exit_code(), 3)
  assert_eq(imported.source(), raw)
  guard imported.to_json()
    is {
      "unresolved": Array([{ "code": "external-document-not-expanded", .. }]),
      ..
    } else {
    fail("external inventory ignored")
  }
}

///|
test "SPDX round trip and SARIF preserve source and unknown number tokens" {
  let raw = "\n " +
    spdx(spdx_package("SPDXRef-a", "1.0.0")).replace(
      old="\"packages\":",
      new="\"extension\":900719925474099312345,\"packages\":",
    )
  let first = @mtyuejian.read_bom(raw, origin="fixture")
  assert_eq(
    first.to_json().stringify(),
    @mtyuejian.read_bom(first.source(), origin="fixture").to_json().stringify(),
  )
  guard first.assess(cargo_snapshot()).to_sarif(bom_uri="bom.json")
    is {
      "runs": Array([{ "properties": { "yuejian/exit_code": 1, .. }, .. }]),
      ..
    } else {
    fail("SPDX SARIF lost outer gate")
  }
}

///|
test "SPDX malformed IDs headers and references reject then recover" {
  let base = spdx(spdx_package("SPDXRef-a", "1.0.0"))
  for
    raw in [
      base.replace(old="SPDX-2.3", new="SPDX-3.0"),
      base.replace(old="SPDXRef-a", new="SPDXRef-a/b"),
      base.replace(old="SPDXRef-a", new="SPDXRef-DOCUMENT"),
      spdx(
        spdx_package("SPDXRef-a", "1.0.0") +
        "," +
        spdx_package("SPDXRef-a", "2.0.0"),
      ),
      base.replace(
        old="\"externalRefs\":[",
        new="\"externalRefs\":false,\"unused\":[",
      ),
    ] {
    try @mtyuejian.read_spdx(raw) catch {
      _ => ()
    } noraise {
      _ => fail("invalid SPDX accepted")
    }
  }
  assert_eq(@mtyuejian.read_spdx(base).assess(cargo_snapshot()).exit_code(), 1)
}

///|
test "BOM detection refuses absent or competing format selectors" {
  for
    raw in [
      "{}",
      spdx("").replace(
        old="\"packages\":",
        new="\"bomFormat\":\"CycloneDX\",\"packages\":",
      ),
    ] {
    try @mtyuejian.read_bom(raw) catch {
      _ => ()
    } noraise {
      _ => fail("ambiguous BOM guessed")
    }
  }
}

///|
test "SPDX package budget and deterministic inventory order" {
  let rows = Array::makei(1024, i => {
    spdx_package("SPDXRef-" + i.to_string(), "2.0.0")
  })
  let first = @mtyuejian.read_spdx(spdx(rows.join(",")))
    .inventory_json()
    .stringify()
  rows.sort_by((a, b) => b.compare(a))
  assert_eq(
    first,
    @mtyuejian.read_spdx(spdx(rows.join(","))).inventory_json().stringify(),
  )
  rows.push(spdx_package("SPDXRef-overflow", "2.0.0"))
  try @mtyuejian.read_spdx(spdx(rows.join(","))) catch {
    _ => ()
  } noraise {
    _ => fail("package limit ignored")
  }
  assert_eq(
    @mtyuejian.read_spdx(spdx("")).assess(cargo_snapshot()).exit_code(),
    3,
  )
}
