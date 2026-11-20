///|
fn inventory_source(version : String) -> String raise {
  @mtyuejian.inventory_json([
    @mtyuejian.Package::new(
      id="test",
      ecosystem="example",
      name="demo",
      version~,
    ),
  ]).stringify()
}

///|
fn source_region(row : Json) -> Json raise {
  guard row
    is {
      "locations": Array([{ "physicalLocation": { "region": region, .. }, .. }]),
      ..
    } else {
    fail("missing source region")
  }
  region
}

///|
test "located SARIF anchors exact version token including quotes" {
  let raw = inventory_source("1.0.0")
  guard raw.split_once("\"version\":") is Some((prefix, _)) else {
    fail("version missing")
  }
  let start = prefix.length() + "\"version\":".length()
  let output = delivery("1.0.0")
    .assessment()
    .to_sarif(inventory_uri="inventory.json", inventory_source=raw)
  assert_eq(source_region(sarif_rows(output)[0]), {
    "startLine": 1,
    "startColumn": Json(start + 1),
    "endLine": 1,
    "endColumn": Json(start + 8),
  })
  guard sarif_run(output)["properties"]
    is { "yuejian/location_source": String(source), .. } else {
    fail("location source lost")
  }
  assert_eq(source, raw)
  assert_eq(sarif_run(output)["columnKind"], Json("utf16CodeUnits"))
}

///|
test "line mapping handles LF CRLF bare CR and tab as one UTF16 unit" {
  for newline in ["\n", "\r\n", "\r"] {
    let raw = inventory_source("1.0.0").replace(
      old="\"version\":",
      new="\"version\":" + newline + "\t",
    )
    let output = delivery("1.0.0")
      .assessment()
      .to_sarif(inventory_uri="inventory.json", inventory_source=raw)
    assert_eq(source_region(sarif_rows(output)[0]), {
      "startLine": 2,
      "startColumn": 2,
      "endLine": 2,
      "endColumn": 9,
    })
  }
}

///|
test "UTF16 columns count Unicode surrogate pairs and raw JSON escapes" {
  let item = @mtyuejian.Package::new(
    id="审查😀",
    ecosystem="example",
    name="demo",
    version="1.0.0",
  )
  let snapshot = @mtyuejian.Snapshot::new([
    @mtyuejian.read_advisory(sample(semver("[{\"introduced\":\"0\"}]"))),
  ])
  let result = @mtyuejian.assess(snapshot, [item])
  let raw = @mtyuejian.inventory_json([item]).stringify()
  assert_true(raw.contains("😀"))
  guard raw.split_once("\"version\":") is Some((prefix, _)) else {
    fail("version missing")
  }
  let expected = prefix.length() + "\"version\":".length() + 1
  let region = source_region(
    sarif_rows(
      result.to_sarif(inventory_uri="inventory.json", inventory_source=raw),
    )[0],
  )
  guard region is { "startColumn": Number(column, ..), .. } else {
    fail("column missing")
  }
  assert_eq(column, expected.to_double())
  let escaped = raw.replace(old="\"version\":", new="\"ver\\u0073ion\":")
  guard source_region(
      sarif_rows(
        result.to_sarif(
          inventory_uri="inventory.json",
          inventory_source=escaped,
        ),
      )[0],
    )
    is { "startColumn": Number(escaped_column, ..), .. } else {
    fail("escaped key not located")
  }
  assert_eq(escaped_column, (expected + 5).to_double())
}

///|
test "location binding matches IDs rather than sorted assessment positions" {
  let a = @mtyuejian.Package::new(
    id="a",
    ecosystem="example",
    name="demo",
    version="1.0.0",
  )
  let b = @mtyuejian.Package::new(
    id="b",
    ecosystem="example",
    name="demo",
    version="2.0.0",
  )
  let snapshot = @mtyuejian.Snapshot::new([
    @mtyuejian.read_advisory(sample(semver("[{\"introduced\":\"0\"}]"))),
  ])
  let raw = "{\"schema_version\":1,\"packages\":[" +
    b.to_json().stringify() +
    "," +
    a.to_json().stringify() +
    "]}"
  let rows = sarif_rows(
    @mtyuejian.assess(snapshot, [a, b]).to_sarif(
      inventory_uri="inventory.json",
      inventory_source=raw,
    ),
  )
  guard source_region(rows[0]) is { "startColumn": Number(first, ..), .. } &&
    source_region(rows[1]) is { "startColumn": Number(second, ..), .. } else {
    fail("region absent")
  }
  assert_true(first > second)
}

///|
test "unrelated or malformed location inventory is rejected without changing assessment" {
  let result = delivery("1.0.0").assessment()
  let raw = inventory_source("1.0.0")
  for
    wrong in [
      inventory_source("2.0.0"),
      raw.replace(old="\"test\"", new="\"other\""),
      raw.replace(old="example", new="other"),
      raw.replace(old="demo", new="other"),
      raw + " false",
      "{\"schema_version\":1,\"packages\":[]}",
    ] {
    try
      result.to_sarif(inventory_uri="inventory.json", inventory_source=wrong)
    catch {
      _ => ()
    } noraise {
      _ => fail("unrelated source accepted")
    }
  }
  assert_eq(result.exit_code(), 1)
  result.to_sarif(inventory_uri="inventory.json", inventory_source=raw)
  |> ignore
}

///|
test "CycloneDX and SPDX locations follow real version fields" {
  for
    (raw, key) in [
      (bom(component("a", "1.0.0")), "\"version\":"),
      (spdx(spdx_package("SPDXRef-a", "1.0.0")), "\"versionInfo\":"),
    ] {
    let result = @mtyuejian.read_bom(raw).assess(cargo_snapshot())
    guard raw.split_once(key) is Some((prefix, _)) else {
      fail("version key missing")
    }
    let start = prefix.length() + key.length()
    let output = result.to_sarif(bom_uri="bom.json", locate=true)
    assert_eq(source_region(sarif_rows(output)[0]), {
      "startLine": 1,
      "startColumn": Json(start + 1),
      "endLine": 1,
      "endColumn": Json(start + 8),
    })
  }
}

///|
test "unresolved BOM nodes get real object spans and missing arrays get no fake region" {
  let prefix = "{\"bomFormat\":\"CycloneDX\",\"specVersion\":\"1.6\",\"components\":["
  let result = @mtyuejian.read_bom(prefix + "{}]}").assess(cargo_snapshot())
  assert_eq(
    source_region(
      sarif_rows(result.to_sarif(bom_uri="bom.json", locate=true))[0],
    ),
    {
      "startLine": 1,
      "startColumn": Json(prefix.length() + 1),
      "endLine": 1,
      "endColumn": Json(prefix.length() + 3),
    },
  )
  let absent = @mtyuejian.read_bom(
    "{\"bomFormat\":\"CycloneDX\",\"specVersion\":\"1.6\"}",
  ).assess(cargo_snapshot())
  guard sarif_rows(absent.to_sarif(bom_uri="bom.json", locate=true))[0]
    is {
      "locations": Array([{ "physicalLocation": Object(location), .. }]),
      ..
    } else {
    fail("artifact missing")
  }
  assert_true(!location.contains("region"))
}

///|
test "nested subject locations and escaped text do not confuse structural indexing" {
  let raw = "{\"bomFormat\":\"CycloneDX\",\"specVersion\":\"1.6\",\"metadata\":{\"comment\":\"fake \\\"version\\\": 0\\n\",\"component\":" +
    component("subject", "1.0.0") +
    "}}"
  let result = @mtyuejian.read_bom(raw).assess(cargo_snapshot())
  guard source_region(
      sarif_rows(result.to_sarif(bom_uri="bom.json", locate=true))[0],
    )
    is { "startLine": 1, .. } else {
    fail("escaped newline became a source newline")
  }
  let nested = bom(
    component("a", "2.0.0").replace(
      old="\"type\":",
      new="\"components\":[" + component("b", "1.0.0") + "],\"type\":",
    ),
  )
  let rows = sarif_rows(
    @mtyuejian.read_bom(nested)
    .assess(cargo_snapshot())
    .to_sarif(bom_uri="bom.json", locate=true),
  )
  for row in rows {
    source_region(row) |> ignore
  }
}

///|
test "source locations preserve fingerprints verdict and archived receipt behavior" {
  let saved = delivery("1.0.0")
  let before = saved.to_json().stringify()
  let plain = saved.assessment().to_sarif(inventory_uri="inventory.json")
  let located = saved
    .assessment()
    .to_sarif(
      inventory_uri="inventory.json",
      inventory_source=inventory_source("1.0.0"),
    )
  assert_eq(
    fingerprint(sarif_rows(plain)[0]),
    fingerprint(sarif_rows(located)[0]),
  )
  assert_eq(saved.to_json().stringify(), before)
  assert_eq(@mtyuejian.verify_delivery(before).assessment().exit_code(), 1)
}
