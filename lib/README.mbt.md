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
  assert_eq(result.outcomes(), [@mtyuejian.Affected])
  assert_eq(result.exit_code(), 1)
}
```
