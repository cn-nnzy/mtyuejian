///|
test "API package fields reject unpaired surrogates before assessment or serialization" {
  for units in [[0xD800], [0xDC00], [0xD800, 65], [0xD800, 0xD800]] {
    let invalid = String::from_array(units.map(u => u.unsafe_to_char()))
    for field in ["id", "ecosystem", "name", "version"] {
      try
        @mtyuejian.Package::new(
          id=if field == "id" { invalid } else { "a" },
          ecosystem=if field == "ecosystem" { invalid } else { "example" },
          name=if field == "name" { invalid } else { "demo" },
          version=if field == "version" { invalid } else { "1.0.0" },
        )
      catch {
        @mtyuejian.Invalid(code~, path~, ..) => {
          assert_eq(code, "invalid-unicode")
          assert_eq(path, "/" + field)
        }
      } noraise {
        _ => fail("API accepted ill-formed UTF-16")
      }
    }
  }
}

///|
test "API origin labels reject invalid Unicode before saving evidence" {
  let invalid = String::from_array([(0xD800).unsafe_to_char()])
  try @mtyuejian.read_advisory(sample("[]"), origin=invalid) catch {
    @mtyuejian.Invalid(code~, path~, ..) => {
      assert_eq(code, "invalid-unicode")
      assert_eq(path, "/origin")
    }
  } noraise {
    _ => fail("Advisory accepted a lossy origin")
  }
  try @mtyuejian.read_bom(bom(component("a", "2.0.0")), origin=invalid) catch {
    @mtyuejian.Invalid(code~, path~, ..) => {
      assert_eq(code, "invalid-unicode")
      assert_eq(path, "/origin")
    }
  } noraise {
    _ => fail("BOM accepted a lossy origin")
  }
}

///|
test "valid non-BMP API text survives inventory and receipt round trips after errors" {
  let item = @mtyuejian.Package::new(
    id="安装😀",
    ecosystem="example",
    name="demo",
    version="1.0.0+构建😀",
  )
  let encoded = @mtyuejian.inventory_json([item]).stringify()
  assert_eq(
    @mtyuejian.inventory_json(@mtyuejian.read_inventory(encoded)).stringify(),
    encoded,
  )
  let snapshot = @mtyuejian.Snapshot::new([
    @mtyuejian.read_advisory(sample("[]"), origin="审查😀"),
  ])
  let receipt = @mtyuejian.capture(snapshot, [item])
  assert_eq(
    @mtyuejian.verify_delivery(receipt.to_json().stringify()).digest(),
    receipt.digest(),
  )
}

///|
fn large_api_inventory(
  count : Int32,
  value : String,
) -> Array[@mtyuejian.Package] raise @mtyuejian.InputError {
  Array::makei(count, i => {
    @mtyuejian.Package::new(
      id=i.to_string() + value[3:].to_owned(),
      ecosystem=value,
      name=value,
      version=value,
    )
  })
}

///|
test "inventory encoder refuses aggregate payloads its paired reader cannot consume" {
  let value = "x".repeat(4096)
  try @mtyuejian.inventory_json(large_api_inventory(64, value)) catch {
    @mtyuejian.Invalid(code~, ..) => assert_eq(code, "document-limit")
  } noraise {
    _ => fail("Encoder produced an unreadable inventory")
  }
  let encoded = @mtyuejian.inventory_json(large_api_inventory(63, value)).stringify()
  assert_true(encoded.length() <= 1048576)
  assert_eq(
    @mtyuejian.inventory_json(@mtyuejian.read_inventory(encoded)).stringify(),
    encoded,
  )
}

///|
test "inventory size checks include JSON escaping rather than only field lengths" {
  let value = "x" + "\u{0000}".repeat(4095)
  try @mtyuejian.inventory_json(large_api_inventory(12, value)) catch {
    @mtyuejian.Invalid(code~, ..) => assert_eq(code, "document-limit")
  } noraise {
    _ => fail("Escaping exceeded the reader budget")
  }
  let encoded = @mtyuejian.inventory_json(large_api_inventory(8, value)).stringify()
  assert_eq(
    @mtyuejian.inventory_json(@mtyuejian.read_inventory(encoded)).stringify(),
    encoded,
  )
}

///|
test "encoded inventory admits its exact limit and rejects one additional unit" {
  let value = "x".repeat(4096)
  let items = large_api_inventory(64, value)
  let unchecked : Json = {
    "schema_version": 1,
    "packages": Json(items.map(p => p.to_json())),
  }
  let excess = unchecked.stringify().length() - 1048576
  assert_true(excess > 0 && excess < 4096)
  let version = value[0:4096 - excess].to_owned()
  items[0] = @mtyuejian.Package::new(
    id="0" + value[3:].to_owned(),
    ecosystem=value,
    name=value,
    version~,
  )
  let encoded = @mtyuejian.inventory_json(items).stringify()
  assert_eq(encoded.length(), 1048576)
  assert_eq(
    @mtyuejian.inventory_json(@mtyuejian.read_inventory(encoded)).stringify(),
    encoded,
  )
  items[0] = @mtyuejian.Package::new(
    id="0" + value[3:].to_owned(),
    ecosystem=value,
    name=value,
    version=version + "x",
  )
  try @mtyuejian.inventory_json(items) catch {
    @mtyuejian.Invalid(code~, ..) => assert_eq(code, "document-limit")
  } noraise {
    _ => fail("One unit over the inventory budget was accepted")
  }
}
