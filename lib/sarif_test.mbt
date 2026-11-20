///|
fn sarif_run(log : Json) -> Map[String, Json] raise {
  guard log is { "version": "2.1.0", "runs": Array([Object(run)]), .. } else {
    fail("invalid SARIF envelope")
  }
  run
}

///|
fn sarif_rows(log : Json) -> Array[Json] raise {
  guard sarif_run(log)["results"] is Array(rows) else {
    fail("missing results")
  }
  rows
}

///|
fn fingerprint(row : Json) -> String raise {
  guard row
    is {
      "partialFingerprints": { "yuejian/identity/v1": String(value), .. },
      ..
    } else {
    fail("missing stable identity")
  }
  assert_eq(value.length(), 64)
  value
}

///|
test "SARIF preserves the report gate and keeps pass results distinct from findings" {
  for
    (version, kind, level, code) in [
      ("1.0.0", "fail", "error", 1),
      ("2.0.0", "pass", "none", 0),
      ("invalid", "fail", "warning", 3),
    ] {
    let result = delivery(version).assessment()
    let log = result.to_sarif(inventory_uri="input/packages.json")
    let run = sarif_run(log)
    guard run["properties"]
      is {
        "yuejian/report": report,
        "yuejian/exit_code": Number(exit_code, ..),
        ..
      } else {
      fail("report gate missing")
    }
    assert_eq(report.stringify(), result.to_json().stringify())
    assert_eq(exit_code, code.to_double())
    guard sarif_rows(log) is [row] &&
      row is { "kind": String(k), "level": String(l), .. } else {
      fail("missing decision")
    }
    assert_eq(k, kind)
    assert_eq(l, level)
  }
}

///|
test "SARIF fingerprints follow installation identity across upgrades and URI changes" {
  let before = sarif_rows(
      delivery("1.0.0").assessment().to_sarif(inventory_uri="old.json"),
    )[0]
  let current = sarif_rows(
      delivery("2.0.0").assessment().to_sarif(inventory_uri="new.json"),
    )[0]
  assert_eq(fingerprint(before), fingerprint(current))
  let raw = sample(semver("[{\"introduced\":\"0\"}]"))
  let a = evaluate(raw, "1.0.0").to_sarif(inventory_uri="in.json")
  let b = evaluate(raw.replace(old="x_TEST-1", new="x_OTHER-1"), "1.0.0").to_sarif(
    inventory_uri="in.json",
  )
  assert_true(fingerprint(sarif_rows(a)[0]) != fingerprint(sarif_rows(b)[0]))
  let snap = @mtyuejian.Snapshot::new([@mtyuejian.read_advisory(raw)])
  let renamed = @mtyuejian.assess(snap, [
    @mtyuejian.Package::new(
      id="renamed",
      ecosystem="example",
      name="demo",
      version="1.0.0",
    ),
  ]).to_sarif(inventory_uri="in.json")
  assert_true(
    fingerprint(sarif_rows(a)[0]) != fingerprint(sarif_rows(renamed)[0]),
  )
}

///|
test "known hits with incomplete evidence produce a distinct completeness warning" {
  let ranges = "[{\"type\":\"SEMVER\",\"events\":[{\"introduced\":\"0\"}]},{\"type\":\"ECOSYSTEM\",\"events\":[{\"introduced\":\"0\"}]}]"
  let result = evaluate(sample(ranges), "1.0.0")
  assert_eq(result.exit_code(), 1)
  let rows = sarif_rows(result.to_sarif(inventory_uri="inventory.json"))
  guard rows
    is [
      { "ruleId": "YJ001", "level": "error", .. },
      { "ruleId": "YJ002", "level": "warning", .. },
    ] else {
    fail("incomplete evidence hidden by known hit")
  }
  assert_true(fingerprint(rows[0]) != fingerprint(rows[1]))
}

///|
test "withdrawn records and packages without advisories are evidence warnings" {
  let raw = sample(semver("[{\"introduced\":\"0\"}]")).replace(
    old="\"modified\":",
    new="\"withdrawn\":\"2026-11-19T01:00:00Z\",\"modified\":",
  )
  let snap = @mtyuejian.Snapshot::new([@mtyuejian.read_advisory(raw)])
  for name in ["demo", "absent"] {
    let item = @mtyuejian.Package::new(
      id="test",
      ecosystem="example",
      name~,
      version="1.0.0",
    )
    let result = @mtyuejian.assess(snap, [item])
    guard sarif_rows(result.to_sarif(inventory_uri="inventory.json"))
      is [{ "ruleId": "YJ002", "kind": "fail", "level": "warning", .. }] else {
      fail("missing evidence reported as a version match")
    }
  }
}

///|
test "unscoped advisory entries remain warnings without fabricated inventory locations" {
  let raw = sample(semver("[{\"introduced\":\"0\"},{\"fixed\":\"1.0.0\"}]")).replace(
    old="\"affected\":[",
    new="\"affected\":[{\"ranges\":[]},",
  )
  let result = evaluate(raw, "2.0.0")
  let rows = sarif_rows(result.to_sarif(inventory_uri="inventory.json"))
  guard rows is [_, Object(unscoped)] && unscoped["ruleId"] == Json("YJ002") else {
    fail("unscoped entry lost")
  }
  assert_eq(result.exit_code(), 3)
  // The declaration is in an advisory, not at a guessed inventory coordinate.
  assert_true(
    match unscoped.get("locations") {
      None | Some(Array([])) => true
      _ => false
    },
  )
}

///|
test "SARIF retains lossless source snapshot and makes no source line claims" {
  let raw = " \n" +
    sample(semver("[{\"introduced\":\"0\"}]")).replace(
      old="\"affected\":",
      new="\"extra\":900719925474099312345,\"affected\":",
    )
  let result = evaluate(raw, "1.0.0")
  let log = result.to_sarif(inventory_uri="reports/inventory.json")
  guard sarif_run(log)["properties"] is { "yuejian/snapshot": snapshot, .. } else {
    fail("original evidence lost")
  }
  let restored = @mtyuejian.read_snapshot(snapshot.stringify())
  assert_true(restored.to_json().stringify().contains(raw.escape()))
  guard sarif_rows(log)[0]
    is {
      "locations": Array([{ "physicalLocation": Object(location), .. }]),
      ..
    } else {
    fail("artifact location missing")
  }
  assert_true(!location.contains("region"))
  guard location["artifactLocation"]
    is { "uri": "reports/inventory.json", "index": 0, .. } else {
    fail("artifact identity changed")
  }
}

///|
test "BOM export retains unsupported components and the outer assessment gate" {
  for
    raw in [
      bom(""),
      bom(
        component("a", "2.0.0") +
        "," +
        component("b", "2.0.0").replace(old="pkg:cargo", new="pkg:npm"),
      ),
    ] {
    let result = @mtyuejian.read_cyclonedx(raw).assess(cargo_snapshot())
    let log = result.to_sarif(bom_uri="bom.json")
    let rows = sarif_rows(log)
    assert_true(
      rows.any(row => {
        match row {
          { "ruleId": "YJ003", "level": "warning", .. } => true
          _ => false
        }
      }),
    )
    guard sarif_run(log)["properties"]
      is {
        "yuejian/exit_code": 3,
        "yuejian/report": { "import": { "source": String(source), .. }, .. },
        "yuejian/snapshot": _,
        ..
      } else {
      fail("outer BOM evidence lost")
    }
    assert_eq(source, raw)
  }
}

///|
test "artifact URI restrictions reject ambiguity and recover on subsequent export" {
  let result = delivery("1.0.0").assessment()
  for
    uri in [
      "", "../x.json", "a/../x", "./x", "/x", "a//b", "a/", "C:/x", "https://example.invalid/x",
      "a\\b", "a b", "a%2fb", "清单.json", "a?x", "a#x",
    ] {
    try result.to_sarif(inventory_uri=uri) catch {
      _ => ()
    } noraise {
      _ => fail("ambiguous URI accepted: " + uri)
    }
  }
  result.to_sarif(inventory_uri="reports/in-1_~.json") |> ignore
}

///|
test "component IDs cannot alias missing-identity pointer fingerprints" {
  let raw = bom(
    "{}, {\"bom-ref\":\"/components/0\",\"type\":\"file\",\"name\":\"file\"}",
  )
  let result = @mtyuejian.read_cyclonedx(raw).assess(cargo_snapshot())
  let rows = sarif_rows(result.to_sarif(bom_uri="bom.json"))
  assert_eq(rows.length(), 2)
  assert_true(fingerprint(rows[0]) != fingerprint(rows[1]))
}

///|
test "SARIF output is deterministic and cannot mutate assessments or deliveries" {
  let saved = delivery("1.0.0")
  let before = saved.to_json().stringify()
  let result = saved.assessment()
  let output = result.to_sarif(inventory_uri="in.json")
  let original = output.stringify()
  sarif_run(output)["properties"] = Json::null()
  assert_eq(result.to_sarif(inventory_uri="in.json").stringify(), original)
  assert_eq(saved.to_json().stringify(), before)
  assert_eq(@mtyuejian.verify_delivery(before).assessment().exit_code(), 1)
}
