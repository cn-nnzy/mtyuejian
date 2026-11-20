///|
test "BOM delta separates newly affected from retained absolute findings" {
  let hit = bom_delivery(bom(component("a", "1.0.0")))
  let fixed = bom_delivery(bom(component("a", "2.0.0")))
  assert_eq(@mtyuejian.compare_bom_deliveries(fixed, hit).exit_code(), 1)
  assert_eq(@mtyuejian.compare_bom_deliveries(hit, fixed).exit_code(), 0)
  let retained = @mtyuejian.compare_bom_deliveries(hit, hit)
  assert_eq(retained.exit_code(), 0)
  guard retained.to_json() is { "current_exit_code": 1, .. } else {
    fail("absolute finding hidden by passing delta")
  }
}

///|
test "unresolved-to-resolved identity is visible and requires baseline review" {
  let known = bom(component("a", "2.0.0"))
  let unknown = known.replace(old="pkg:cargo", new="pkg:npm")
  let changed = @mtyuejian.compare_bom_deliveries(
    bom_delivery(unknown),
    bom_delivery(known),
  )
  assert_eq(changed.exit_code(), 3)
  guard changed.to_json()
    is {
      "current_exit_code": 0,
      "component_changes": Array(
        [
          {
            "category": "identity-resolved",
            "current_package": { "id": "a", .. },
            ..
          },
        ],
      ),
      ..
    } else {
    fail("unknown identity silently waived")
  }
}

///|
test "removed unresolved components cannot turn a partial BOM delta green" {
  let known = component("a", "2.0.0")
  let before = bom_delivery(
    bom(
      known +
      "," +
      component("b", "2.0.0").replace(old="pkg:cargo", new="pkg:npm"),
    ),
  )
  let after = bom_delivery(bom(known))
  let changes = @mtyuejian.compare_bom_deliveries(before, after)
  assert_eq(changes.exit_code(), 3)
  guard changes.to_json()
    is {
      "component_changes": Array([{ "category": "removed-unresolved", .. }]),
      ..
    } else {
    fail("unknown evidence disappeared")
  }
}

///|
test "resolved-to-unresolved and empty BOMs stay incomplete" {
  let known = bom_delivery(bom(component("a", "2.0.0")))
  for
    raw in [
      bom(""),
      bom(component("a", "2.0.0").replace(old="pkg:cargo", new="pkg:npm")),
    ] {
    assert_eq(
      @mtyuejian.compare_bom_deliveries(known, bom_delivery(raw)).exit_code(),
      3,
    )
  }
  let empty = bom_delivery(bom(""))
  assert_eq(@mtyuejian.compare_bom_deliveries(empty, empty).exit_code(), 3)
}

///|
test "profile transitions require review even for identical resolved inventory" {
  let a = bom_delivery(bom(component("SPDXRef-a", "2.0.0")))
  let b = bom_delivery(spdx(spdx_package("SPDXRef-a", "2.0.0")))
  let changes = @mtyuejian.compare_bom_deliveries(a, b)
  assert_eq(changes.exit_code(), 3)
  guard changes.to_json()
    is { "profile_changed": true, "current_exit_code": 0, .. } else {
    fail("format transition hidden")
  }
}

///|
test "BOM metadata changes are reported without changing known version evidence" {
  let raw = bom(component("a", "2.0.0"))
  let changed = raw.replace(
    old="\"components\":",
    new="\"extension\":900719925474099312345,\"components\":",
  )
  let delta = @mtyuejian.compare_bom_deliveries(
    bom_delivery(raw),
    bom_delivery(changed),
  )
  assert_eq(delta.exit_code(), 0)
  guard delta.to_json() is { "bom_source_changed": true, .. } else {
    fail("source change hidden")
  }
}

///|
test "BOM delta outputs are deterministic and preserve previous inventory delta behavior" {
  let before = bom_delivery(bom(component("test", "1.0.0")))
  let after = bom_delivery(bom(component("test", "2.0.0")))
  let delta = @mtyuejian.compare_bom_deliveries(before, after)
  let expected = delta.to_json().stringify()
  if delta.to_json() is Object(fields) {
    fields["component_changes"] = Json::null()
  }
  assert_eq(delta.to_json().stringify(), expected)
  assert_eq(
    @mtyuejian.compare_bom_deliveries(
      @mtyuejian.verify_bom_delivery(before.to_json().stringify()),
      @mtyuejian.verify_bom_delivery(after.to_json().stringify()),
    )
    .to_json()
    .stringify(),
    expected,
  )
  let old = @mtyuejian.compare_deliveries(delivery("1.0.0"), delivery("2.0.0"))
  assert_eq(old.exit_code(), 0)
  guard old.to_json()
    is { "entries": Array([{ "category": "no-longer-matched", .. }]), .. } else {
    fail("inventory comparison behavior changed")
  }
}

///|
test "unresolved ID and pointer domains cannot collapse distinct BOM rows" {
  let saved = bom_delivery(
    bom("{}, {\"type\":\"file\",\"bom-ref\":\"/components/0\",\"name\":\"f\"}"),
  )
  guard @mtyuejian.compare_bom_deliveries(saved, saved).to_json()
    is { "component_changes": Array(rows), .. } else {
    fail("unresolved rows absent")
  }
  assert_eq(rows.length(), 2)
}
