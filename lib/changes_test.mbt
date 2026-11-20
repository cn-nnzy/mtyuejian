///|
test "a fixed version becoming affected is a regression" {
  let diff = @mtyuejian.compare_deliveries(delivery("2.0.0"), delivery("1.0.0"))
  assert_eq(diff.exit_code(), 1)
  guard diff.to_json()
    is {
      "entries": Array(
        [{ "category": String(kind), "causes": Array(causes), .. }],
      ),
      ..
    } else {
    fail("missing change")
  }
  assert_eq(kind, "newly-affected")
  assert_eq(causes, [Json("package-version")])
}

///|
test "leaving an affected range is not called a universal fix" {
  let diff = @mtyuejian.compare_deliveries(delivery("1.0.0"), delivery("2.0.0"))
  assert_eq(diff.exit_code(), 0)
  guard diff.to_json()
    is {
      "entries": Array([{ "category": String(kind), .. }]),
      "current_exit_code": Number(code, ..),
      ..
    } else {
    fail("missing change")
  }
  assert_eq(kind, "no-longer-matched")
  assert_eq(code, 0.0)
}

///|
test "retained positives remain visible independently of the delta gate" {
  let diff = @mtyuejian.compare_deliveries(delivery("1.0.0"), delivery("1.0.0"))
  assert_eq(diff.exit_code(), 0)
  guard diff.to_json()
    is {
      "current_exit_code": Number(code, ..),
      "entries": Array([{ "category": String(kind), .. }]),
      ..
    } else {
    fail("current gate missing")
  }
  assert_eq(code, 1.0)
  assert_eq(kind, "unchanged")
}

///|
test "an unsupported current version requires review even with a baseline" {
  let diff = @mtyuejian.compare_deliveries(
    delivery("1.0.0"),
    delivery("v1.0.0"),
  )
  assert_eq(diff.exit_code(), 3)
}

///|
test "dropping an advisory cannot resolve its finding" {
  let prior = delivery("1.0.0")
  let other = @mtyuejian.read_advisory(
    sample(semver("[{\"introduced\":\"0\"},{\"fixed\":\"2.0.0\"}]")).replace(
      old="x_TEST-1",
      new="x_OTHER-1",
    ),
  )
  let current = @mtyuejian.capture(@mtyuejian.Snapshot::new([other]), [
    @mtyuejian.Package::new(
      id="test",
      ecosystem="example",
      name="demo",
      version="2.0.0",
    ),
  ])
  assert_eq(@mtyuejian.compare_deliveries(prior, current).exit_code(), 3)
}

///|
test "reused installation ID with different identity is explicit" {
  let doc = @mtyuejian.read_advisory(
    sample(semver("[{\"introduced\":\"0\"},{\"fixed\":\"2.0.0\"}]")),
  )
  let current = @mtyuejian.capture(@mtyuejian.Snapshot::new([doc]), [
    @mtyuejian.Package::new(
      id="test",
      ecosystem="example",
      name="other",
      version="2.0.0",
    ),
  ])
  let diff = @mtyuejian.compare_deliveries(delivery("2.0.0"), current)
  assert_eq(diff.exit_code(), 3)
  guard diff.to_json() is { "identity_changes": Array([_]), .. } else {
    fail("identity substitution hidden")
  }
}

///|
test "changing an advisory is distinguished from changing a package version" {
  let changed = @mtyuejian.read_advisory(
    sample(semver("[{\"introduced\":\"0\"},{\"fixed\":\"3.0.0\"}]")),
    origin="fixture",
  )
  let current = @mtyuejian.capture(@mtyuejian.Snapshot::new([changed]), [
    @mtyuejian.Package::new(
      id="test",
      ecosystem="example",
      name="demo",
      version="2.0.0",
    ),
  ])
  let diff = @mtyuejian.compare_deliveries(delivery("2.0.0"), current)
  assert_eq(diff.exit_code(), 1)
  guard diff.to_json()
    is { "entries": Array([{ "causes": Array(causes), .. }]), .. } else {
    fail("cause missing")
  }
  assert_eq(causes, [Json("advisory-source")])
}
