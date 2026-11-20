///|
fn main raise {
  let raw =
    #|{"id":"x_EXAMPLE-1","modified":"2026-11-19T00:00:00Z","affected":[{"package":{"ecosystem":"example","name":"demo"},"ranges":[{"type":"SEMVER","events":[{"introduced":"0"},{"fixed":"1.2.0"}]}]}]}
  let doc = @yuejian.read_advisory(raw, origin="consumer example (synthetic)")
  let snap = @yuejian.Snapshot::new([doc])
  let item = @yuejian.Package::new(
    id="demo",
    ecosystem="example",
    name="demo",
    version="1.1.0",
  )
  let report = @yuejian.assess(snap, [item])
  assert_eq(report.outcomes(), [@yuejian.Affected])
  assert_eq(report.exit_code(), 1)
  let receipt = @yuejian.capture(snap, [item])
  // In CI the approved digest comes from a separately reviewed configuration.
  let verified = @yuejian.verify_delivery(
    receipt.to_json().stringify(),
    expected_sha256=receipt.digest(),
  )
  assert_eq(verified.assessment().exit_code(), 1)
  println(report.to_json().stringify())
}
