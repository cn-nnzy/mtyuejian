# Library example

The example uses a synthetic advisory. Use `samples/RUSTSEC-2020-0071.json`
with the CLI for a real source record.

```mbt check
///|
test "assess an exact installed version" {
  let raw =
    #|{"id":"x_EXAMPLE-1","modified":"2026-11-19T00:00:00Z","affected":[{"package":{"ecosystem":"example","name":"demo"},"ranges":[{"type":"SEMVER","events":[{"introduced":"0"},{"fixed":"1.2.0"}]}]}]}
  let snapshot = @mtyuejian.Snapshot::new([@mtyuejian.read_advisory(raw)])
  let installed = @mtyuejian.Package::new(
    id="app/demo",
    ecosystem="example",
    name="demo",
    version="1.1.0",
  )
  let result = @mtyuejian.assess(snapshot, [installed])
  let source = @mtyuejian.inventory_json([installed]).stringify()
  result.to_sarif(inventory_uri="inventory.json", inventory_source=source)
  |> ignore
  assert_eq(result.outcomes(), [@mtyuejian.Affected])
  assert_eq(result.exit_code(), 1)
  let sarif = result.to_sarif(inventory_uri="inventory.json")
  guard sarif
    is {
      "version": "2.1.0",
      "runs": Array([{ "properties": { "yuejian/exit_code": 1, .. }, .. }]),
      ..
    } else {
    fail("SARIF must retain the assessment gate")
  }
}
```

Resolve an existing BOM only when every component has a supported identity.
The exact input remains available for later inspection.

```mbt check
///|
test "import a Cargo BOM without losing its source" {
  let raw =
    #|{"bomFormat":"CycloneDX","specVersion":"1.6","components":[{"type":"library","bom-ref":"app/time","name":"time","version":"0.2.23","purl":"pkg:cargo/time@0.2.23"}]}
  let imported = @mtyuejian.read_cyclonedx(raw)
  let installed = @mtyuejian.read_inventory(
    imported.inventory_json().stringify(),
  )
  assert_eq(installed.length(), 1)
  assert_eq(imported.source(), raw)
  let advisory = @mtyuejian.read_advisory(
    "{\"id\":\"x_ARCHIVE-1\",\"modified\":\"2026-11-20T00:00:00Z\",\"affected\":[]}",
  )
  let receipt = @mtyuejian.capture_bom(
    @mtyuejian.Snapshot::new([advisory]),
    imported,
  )
  let restored = @mtyuejian.verify_bom_delivery(receipt.to_json().stringify())
  assert_eq(restored.digest(), receipt.digest())
  guard restored.alias_review()
    is { "profile": "alias-review-v1", "exit_code": 3, .. } else {
    fail("alias review must retain the outer gate")
  }
  assert_eq(
    @mtyuejian.verify_bom_delivery(
      receipt.to_json().stringify(),
      expected_sha256=receipt.digest(),
    ).digest(),
    receipt.digest(),
  )
  assert_eq(@mtyuejian.compare_bom_deliveries(receipt, restored).exit_code(), 3)
  assert_eq(restored.assessment().exit_code(), 3) // No advisory matches time.
  assert_eq(
    @mtyuejian.read_bom(raw).inventory_json().stringify(),
    imported.inventory_json().stringify(),
  )
}
```
