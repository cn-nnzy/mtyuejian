///|
fn bom(component : String, version~ : String = "1.6") -> String {
  "{\"bomFormat\":\"CycloneDX\",\"specVersion\":\"" +
  version +
  "\",\"components\":[" +
  component +
  "]}"
}

///|
fn component(ref_ : String, version : String) -> String {
  "{\"type\":\"library\",\"bom-ref\":\"" +
  ref_ +
  "\",\"name\":\"demo\",\"version\":\"" +
  version +
  "\",\"purl\":\"pkg:cargo/demo@" +
  version +
  "\"}"
}

///|
fn cargo_snapshot() -> @mtyuejian.Snapshot raise {
  @mtyuejian.Snapshot::new([
    @mtyuejian.read_advisory(
      sample(semver("[{\"introduced\":\"0\"},{\"fixed\":\"2.0.0\"}]")).replace(
        old="example",
        new="crates.io",
      ),
    ),
  ])
}

///|
test "CycloneDX inventory adapter evaluates exact Cargo package identity" {
  for spec in ["1.5", "1.6"] {
    let imported = @mtyuejian.read_cyclonedx(
      bom(component("a", "1.0.0"), version=spec),
    )
    assert_eq(
      @mtyuejian.read_inventory(imported.inventory_json().stringify()).length(),
      1,
    )
    assert_eq(imported.assess(cargo_snapshot()).exit_code(), 1)
  }
}

///|
test "unsupported components remain visible and block partial inventory export" {
  let raw = bom(
    component("a", "2.0.0") +
    "," +
    component("b", "2.0.0").replace(old="pkg:cargo", new="pkg:npm"),
  )
  let imported = @mtyuejian.read_cyclonedx(raw)
  assert_eq(imported.assess(cargo_snapshot()).exit_code(), 3)
  try imported.inventory_json() catch {
    _ => ()
  } noraise {
    _ => fail("partial inventory exported as complete")
  }
  assert_eq(imported.source(), raw)
  guard imported.to_json()
    is { "unresolved": Array([_]), "packages": Array([_]), .. } else {
    fail("component lost")
  }
}

///|
test "known hits retain unresolved components in the same BOM" {
  let raw = bom(
    component("a", "1.0.0") +
    "," +
    component("b", "2.0.0").replace(old="pkg:cargo", new="pkg:npm"),
  )
  let result = @mtyuejian.read_cyclonedx(raw).assess(cargo_snapshot())
  assert_eq(result.exit_code(), 1)
  guard result.to_json() is { "import": { "unresolved": Array([_]), .. }, .. } else {
    fail("unknown component hidden by known hit")
  }
}

///|
test "component metadata and PURL must agree without coercion" {
  for
    replacement in [
      "pkg:cargo/demo@3.0.0", "pkg:cargo/other@2.0.0", "pkg:cargo/demo@2.0.0?repository_url=x",
      "pkg:cargo/demo@2.0.0#src", "pkg:cargo/demo@2.0.0%2Bx", "pkg:cargo/scope/demo@2.0.0",
      "pkg:cargo/demo@v2.0.0",
    ] {
    let raw = bom(
      component("a", "2.0.0").replace(
        old="pkg:cargo/demo@2.0.0",
        new=replacement,
      ),
    )
    assert_eq(
      @mtyuejian.read_cyclonedx(raw).assess(cargo_snapshot()).exit_code(),
      3,
    )
  }
}

///|
test "nested and subject components are accounted for" {
  let parent = component("a", "2.0.0").replace(
    old="\"type\":",
    new="\"components\":[" + component("b", "1.0.0") + "],\"type\":",
  )
  let input = "{\"bomFormat\":\"CycloneDX\",\"specVersion\":\"1.6\",\"metadata\":{\"component\":" +
    component("c", "2.0.0") +
    "},\"components\":[" +
    parent +
    "]}"
  let imported = @mtyuejian.read_cyclonedx(input)
  assert_eq(
    @mtyuejian.read_inventory(imported.inventory_json().stringify()).length(),
    3,
  )
  assert_eq(imported.assess(cargo_snapshot()).exit_code(), 1)
}

///|
test "duplicate BOM references are errors across nested components" {
  let raw = bom(
    component("a", "1.0.0").replace(
      old="\"type\":",
      new="\"components\":[" + component("a", "2.0.0") + "],\"type\":",
    ),
  )
  try @mtyuejian.read_cyclonedx(raw) catch {
    _ => ()
  } noraise {
    _ => fail("duplicate identity accepted")
  }
}

///|
test "component order does not affect exported inventory" {
  let a = component("a", "1.0.0")
  let b = component("b", "2.0.0")
  assert_eq(
    @mtyuejian.read_cyclonedx(bom(a + "," + b)).inventory_json().stringify(),
    @mtyuejian.read_cyclonedx(bom(b + "," + a)).inventory_json().stringify(),
  )
}

///|
test "component nesting and count budgets include exact boundaries" {
  let mut nested = component("leaf", "1.0.0")
  for depth in 2..<=17 {
    nested = component("level" + depth.to_string(), "1.0.0").replace(
      old="\"type\":",
      new="\"components\":[" + nested + "],\"type\":",
    )
    if depth == 16 {
      @mtyuejian.read_cyclonedx(bom(nested)) |> ignore
    }
  }
  try @mtyuejian.read_cyclonedx(bom(nested)) catch {
    _ => ()
  } noraise {
    _ => fail("excess nesting accepted")
  }
  let rows = Array::makei(1024, i => component(i.to_string(), "1.0.0"))
  assert_eq(
    @mtyuejian.read_inventory(
      @mtyuejian.read_cyclonedx(bom(rows.join(",")))
      .inventory_json()
      .stringify(),
    ).length(),
    1024,
  )
  rows.push(component("overflow", "1.0.0"))
  try @mtyuejian.read_cyclonedx(bom(rows.join(","))) catch {
    _ => ()
  } noraise {
    _ => fail("excess count accepted")
  }
  assert_eq(
    @mtyuejian.read_cyclonedx(bom(component("recovered", "2.0.0")))
    .assess(cargo_snapshot())
    .exit_code(),
    0,
  )
}

///|
test "empty unknown and missing identities never pass" {
  for
    raw in [
      bom(""),
      bom("{\"type\":\"library\",\"name\":\"demo\"}"),
      bom("{\"type\":\"file\",\"bom-ref\":\"file\",\"name\":\"file\"}"),
    ] {
    assert_eq(
      @mtyuejian.read_cyclonedx(raw).assess(cargo_snapshot()).exit_code(),
      3,
    )
  }
}

///|
test "source round trip preserves metadata and derived import view" {
  let raw = bom(component("a", "1.0.0")).replace(
    old="\"components\":",
    new="\"extension\":{\"big\":900719925474099312345,\"flag\":false},\"components\":",
  )
  let original = @mtyuejian.read_cyclonedx(raw, origin="fixture")
  let restored = @mtyuejian.read_cyclonedx(original.source(), origin="fixture")
  assert_eq(original.to_json().stringify(), restored.to_json().stringify())
}

///|
test "malformed and unsupported BOM profiles are rejected" {
  for
    raw in [
      bom(component("a", "1.0.0"), version="1.7"),
      bom(component("a", "1.0.0")).replace(old="CycloneDX", new="SPDX"),
      bom(component("a", "1.0.0")).replace(
        old="\"components\":",
        new="\"version\":1.0,\"components\":",
      ),
    ] {
    try @mtyuejian.read_cyclonedx(raw) catch {
      _ => ()
    } noraise {
      _ => fail("invalid BOM accepted")
    }
  }
}
