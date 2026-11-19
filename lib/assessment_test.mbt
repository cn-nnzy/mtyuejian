///|
test "withdrawn and no advisory stay visible and require review" {
  let withdrawn = sample(semver("[{\"introduced\":\"0\"}]")).replace(
    old="\"modified\":",
    new="\"withdrawn\":\"2026-11-19T01:00:00Z\",\"modified\":",
  )
  assert_eq(outcome(withdrawn, "1.0.0"), @mtyuejian.Withdrawn)
  assert_eq(evaluate(withdrawn, "1.0.0").exit_code(), 3)
  let snap = @mtyuejian.Snapshot::new([@mtyuejian.read_advisory(withdrawn)])
  let item = @mtyuejian.Package::new(
    id="other",
    ecosystem="different",
    name="demo",
    version="1.0.0",
  )
  let result = @mtyuejian.assess(snap, [item])
  assert_eq(result.outcomes(), [@mtyuejian.NoAdvisory])
  assert_eq(result.exit_code(), 3)
}

///|
test "unscoped active entries prevent a complete negative assessment" {
  let raw = sample(semver("[{\"introduced\":\"0\"},{\"fixed\":\"1.0.0\"}]")).replace(
    old="\"affected\":[",
    new="\"affected\":[{\"ranges\":[{\"type\":\"GIT\",\"repo\":\"https://example.invalid/r\",\"events\":[{}]}]},",
  )
  let result = evaluate(raw, "2.0.0")
  assert_eq(result.outcomes(), [@mtyuejian.NotMatched])
  assert_eq(result.exit_code(), 3)
  guard result.to_json() is { "unscoped_entries": Array([_]), .. } else {
    fail("missing unscoped diagnostic")
  }
}

///|
test "empty matching entry is unknown" {
  assert_eq(outcome(sample("[]"), "1.0.0"), @mtyuejian.Undetermined)
}

///|
test "report order ignores caller ordering and returned JSON is independent" {
  let a = @mtyuejian.read_advisory(sample(semver("[{\"introduced\":\"0\"}]")))
  let b = @mtyuejian.read_advisory(
    sample(semver("[{\"introduced\":\"0\"}]")).replace(
      old="x_TEST-1",
      new="x_A-2",
    ),
  )
  let one = @mtyuejian.Package::new(
    id="b",
    ecosystem="example",
    name="demo",
    version="1.0.0",
  )
  let two = @mtyuejian.Package::new(
    id="aa",
    ecosystem="example",
    name="demo",
    version="2.0.0",
  )
  let first = @mtyuejian.assess(@mtyuejian.Snapshot::new([a, b]), [one, two])
  let second = @mtyuejian.assess(@mtyuejian.Snapshot::new([b, a]), [two, one])
  assert_eq(first.to_json().stringify(), second.to_json().stringify())
  let before = first.to_json().stringify()
  if first.to_json() is Object(fields) {
    fields["exit_code"] = Json(0)
  }
  let outcomes = first.outcomes()
  outcomes[0] = @mtyuejian.NotMatched
  assert_eq(first.to_json().stringify(), before)
  assert_eq(first.exit_code(), 1)
}

///|
test "assessing a decoded snapshot preserves prior behavior" {
  let snap = @mtyuejian.Snapshot::new([
    @mtyuejian.read_advisory(
      sample(semver("[{\"introduced\":\"0\"},{\"fixed\":\"2.0.0\"}]")),
    ),
  ])
  let items = [
    @mtyuejian.Package::new(
      id="test",
      ecosystem="example",
      name="demo",
      version="1.0.0",
    ),
  ]
  let before = @mtyuejian.assess(snap, items).to_json().stringify()
  let after = @mtyuejian.assess(
      @mtyuejian.read_snapshot(snap.to_json().stringify()),
      items,
    )
    .to_json()
    .stringify()
  assert_eq(before, after)
}
