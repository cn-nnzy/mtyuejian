///|
fn main raise {
  let raw =
    #|{"id":"x_CONSUMER-1","modified":"2026-11-27T00:00:00Z","affected":[{"package":{"ecosystem":"crates.io","name":"demo"},"ranges":[{"type":"ECOSYSTEM","events":[{"introduced":"0"},{"fixed":"2.0.0"}]}]}]}
  let legacy = @yuejian.Snapshot::new([@yuejian.read_advisory(raw)])
  let installed = @yuejian.Package::new(id="demo", ecosystem="crates.io", name="demo", version="1.0.0")
  assert_eq(@yuejian.assess(legacy, [installed]).exit_code(), 3)
  let selected = legacy.with_crates_io()
  let receipt = @yuejian.capture(selected, [installed])
  let restored = @yuejian.verify_delivery(receipt.to_json().stringify(), expected_sha256=receipt.digest())
  assert_eq(restored.assessment().outcomes(), [@yuejian.Affected])
  assert_eq(restored.assessment().coverage().stringify(), receipt.assessment().coverage().stringify())
  assert_eq(@yuejian.read_snapshot(selected.to_json().stringify()).to_json().stringify(), selected.to_json().stringify())
  assert_true(restored.to_markdown().contains("crates-io-semver-v1"))
  let first = @yuejian.read_bom(
    "{\"bomFormat\":\"CycloneDX\",\"specVersion\":\"1.7\",\"components\":[{\"bom-ref\":\"a\",\"type\":\"library\",\"name\":\"demo\",\"version\":\"1.0.0\",\"purl\":\"pkg:cargo/demo@1.0.0\"}]}",
  )
  let second = @yuejian.read_bom(
    "{\"spdxVersion\":\"SPDX-2.3\",\"SPDXID\":\"SPDXRef-DOCUMENT\",\"packages\":[{\"SPDXID\":\"SPDXRef-b\",\"name\":\"demo\",\"versionInfo\":\"1.0.0\",\"externalRefs\":[{\"referenceCategory\":\"PACKAGE-MANAGER\",\"referenceType\":\"purl\",\"referenceLocator\":\"pkg:cargo/demo@1.0.0\"}]}]}",
  )
  assert_eq(@yuejian.compare_bom_scope(first, second).exit_code(), 0)
  println("Independent consumer verified explicit crates.io ordering and receipt replay")
}
