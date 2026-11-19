///|
fn invalid_advisory(input : String, expected : String) -> Unit raise {
  try @mtyuejian.read_advisory(input) catch {
    error => {
      guard error.to_json() is { "code": String(code), .. } else {
        fail("missing diagnostic code")
      }
      assert_eq(code, expected)
    }
  } noraise {
    _ => fail("invalid advisory accepted")
  }
}

///|
test "duplicate keys include equivalent escaped spelling" {
  invalid_advisory("{\"id\":\"x_A\",\"\\u0069d\":\"x_B\"}", "duplicate-key")
  invalid_advisory(
    sample("[]").replace(
      old="\"versions\":[]",
      new="\"versions\":[],\"versions\":[]",
    ),
    "duplicate-key",
  )
}

///|
test "JSON grammar rejects trailing data and malformed numbers" {
  invalid_advisory(sample("[]") + " null", "trailing-json")
  invalid_advisory("{\"x\":01}", "invalid-json")
  invalid_advisory("{\"x\":1.}", "invalid-json-number")
  invalid_advisory("{\"x\":1e+}", "invalid-json-number")
  invalid_advisory("{\"x\":NaN}", "invalid-json")
  invalid_advisory("{\"x\":true,}", "invalid-json")
}

///|
test "Unicode escapes fail clearly and valid pairs survive" {
  invalid_advisory("{\"x\":\"\\uD800\"}", "invalid-json-string")
  invalid_advisory("{\"x\":\"\\uDC00\"}", "invalid-json-string")
  let raw = sample("[]").replace(
    old="\"versions\":[]",
    new="\"versions\":[],\"extension\":\"\\uD83D\\uDE00\"",
  )
  assert_eq(@mtyuejian.read_advisory(raw).source(), raw)
}

///|
test "contradictory and ambiguous event boundaries are rejected" {
  for
    events in [
      "[{\"fixed\":\"1.0.0\"}]", "[{\"introduced\":\"0\"},{\"introduced\":\"1.0.0\"}]",
    ] {
    invalid_advisory(sample(semver(events)), "contradictory-events")
  }
  invalid_advisory(
    sample(semver("[{\"introduced\":\"1.0.0\"},{\"fixed\":\"1.0.0+meta\"}]")),
    "ambiguous-events",
  )
  invalid_advisory(
    sample(semver("[{\"introduced\":\"0\",\"fixed\":\"1.0.0\"}]")),
    "invalid-event",
  )
  invalid_advisory(
    sample(semver("[{\"introduced\":\"0\"},{\"future_event\":\"1.0.0\"}]")),
    "unsupported-event",
  )
}

///|
test "invalid semver boundaries are not interpreted as strings" {
  invalid_advisory(
    sample(semver("[{\"introduced\":\"v1.0.0\"}]")),
    "invalid-semver",
  )
  invalid_advisory(sample(semver("[]")), "empty-events")
  invalid_advisory(
    sample(semver("[{\"limit\":\"*\"}]")),
    "missing-introduction",
  )
}

///|
test "schema profile and calendar dates are checked" {
  invalid_advisory(
    sample("[]").replace(
      old="\"modified\":",
      new="\"schema_version\":\"2.0.0\",\"modified\":",
    ),
    "unsupported-osv-version",
  )
  invalid_advisory(
    sample("[]").replace(old="2026-11-19T00:00:00Z", new="2026-02-29T00:00:00Z"),
    "invalid-timestamp",
  )
  invalid_advisory(
    sample("[]").replace(old="2026-11-19T00:00:00Z", new="2026-11-19T00:00:60Z"),
    "invalid-timestamp",
  )
  @mtyuejian.read_advisory(
    sample("[]").replace(
      old="2026-11-19T00:00:00Z",
      new="2024-02-29T23:59:59.123+08:00",
    ),
  )
  |> ignore
}

///|
test "snapshot round trip preserves all original source tokens" {
  let original = sample("[]").replace(
    old="\"versions\":[]",
    new="\"versions\":[],\"unknown\":{\"big\":900719925474099312345,\"exponent\":1e9999,\"ok\":false,\"nil\":null}",
  )
  let snap = @mtyuejian.Snapshot::new([
    @mtyuejian.read_advisory(original, origin="fixture"),
  ])
  let encoded = snap.to_json().stringify()
  let decoded = @mtyuejian.read_snapshot(encoded)
  assert_eq(decoded.to_json().stringify(), encoded)
  guard decoded.to_json()
    is { "documents": Array([{ "text": String(source), .. }]), .. } else {
    fail("source missing")
  }
  assert_eq(source, original)
}

///|
test "snapshots reject duplicate IDs and conflicting revisions" {
  let a = @mtyuejian.read_advisory(sample("[]"))
  let b = @mtyuejian.read_advisory(
    sample("[]").replace(old="2026-11-19", new="2026-11-18"),
  )
  for docs in [[a, a], [a, b]] {
    try @mtyuejian.Snapshot::new(docs) catch {
      error =>
        assert_true(
          error.to_json().stringify().contains("duplicate-advisory-id"),
        )
    } noraise {
      _ => fail("duplicate ID accepted")
    }
  }
}

///|
test "inventory is closed and round trips deterministically" {
  let raw = "{\"schema_version\":1,\"packages\":[{\"id\":\"b\",\"ecosystem\":\"example\",\"name\":\"demo\",\"version\":\"1.0.0\"},{\"id\":\"a\",\"ecosystem\":\"example\",\"name\":\"demo\",\"version\":\"2.0.0\"}]}"
  let encoded = @mtyuejian.inventory_json(@mtyuejian.read_inventory(raw)).stringify()
  assert_eq(
    @mtyuejian.inventory_json(@mtyuejian.read_inventory(encoded)).stringify(),
    encoded,
  )
  for
    bad in [
      raw.replace(old="\"id\":\"a\"", new="\"id\":\"b\""),
      raw.replace(old="\"name\":", new="\"typo\":"),
    ] {
    try @mtyuejian.read_inventory(bad) catch {
      _ => ()
    } noraise {
      _ => fail("invalid inventory accepted")
    }
  }
}

///|
test "resource depth and document budgets reject before evaluation" {
  let mut nested = "0"
  for _ in 0..<50 {
    nested = "[" + nested + "]"
  }
  invalid_advisory(nested, "json-limit")
  invalid_advisory(" ".repeat(1048577), "document-limit")
}

///|
test "an error does not contaminate the next document" {
  invalid_advisory("{", "invalid-json")
  let good = sample(semver("[{\"introduced\":\"0\"}]"))
  assert_eq(evaluate(good, "1.0.0").exit_code(), 1)
  assert_eq(
    evaluate(good, "1.0.0").to_json().stringify(),
    evaluate(good, "1.0.0").to_json().stringify(),
  )
}

///|
test "snapshot source budget includes origin labels and escaped envelopes" {
  let base = sample(semver("[{\"introduced\":\"0\"}]"))
  // Large whitespace inputs must survive envelope escaping and budget checks.
  let original = "\t".repeat(250000) + base
  let snap = @mtyuejian.Snapshot::new([
    @mtyuejian.read_advisory(original, origin="\t".repeat(4095) + "x"),
  ])
  let encoded = snap.to_json().stringify()
  assert_eq(@mtyuejian.read_snapshot(encoded).to_json().stringify(), encoded)
  let too_large = " ".repeat(262144 - base.length()) + base
  try
    @mtyuejian.Snapshot::new([@mtyuejian.read_advisory(too_large, origin="x")])
  catch {
    error => assert_true(error.to_json().stringify().contains("snapshot-size"))
  } noraise {
    _ => fail("source label escaped snapshot budget")
  }
}

///|
test "JSON metadata survives booleans arrays decimals and escaped names" {
  let source = sample("[]").replace(
    old="\"versions\":[]",
    new="\"versions\":[],\"extension\":[true,false,null,-0,1.25e-3,{\"a/b~c\":\"ok\"}]",
  )
  assert_eq(@mtyuejian.read_advisory(source).source(), source)
  invalid_advisory(
    sample(semver("[{\"introduced\":\"0\"}]")).replace(
      old="\"events\":",
      new="\"extension\":true,\"events\":",
    ),
    "unsupported-field",
  )
}
