///|
fn delivery(version : String) -> @mtyuejian.Delivery raise {
  let doc = @mtyuejian.read_advisory(
    sample(semver("[{\"introduced\":\"0\"},{\"fixed\":\"2.0.0\"}]")),
    origin="fixture",
  )
  @mtyuejian.capture(@mtyuejian.Snapshot::new([doc]), [
    @mtyuejian.Package::new(
      id="test",
      ecosystem="example",
      name="demo",
      version~,
    ),
  ])
}

///|
test "delivery round trip recomputes the original report and preserves the verdict" {
  for version in ["1.0.0", "2.0.0", "not-semver"] {
    let original = delivery(version)
    let restored = @mtyuejian.verify_delivery(original.to_json().stringify())
    assert_eq(restored.digest(), original.digest())
    assert_eq(restored.to_json().stringify(), original.to_json().stringify())
    assert_eq(
      restored.assessment().to_json().stringify(),
      original.assessment().to_json().stringify(),
    )
    assert_eq(
      restored.assessment().exit_code(),
      original.assessment().exit_code(),
    )
  }
}

///|
test "all three delivery payloads and the digest are checked" {
  for key in ["inventory", "snapshot", "report", "sha256"] {
    let envelope = delivery("1.0.0").to_json()
    guard envelope is Object(fields) && fields[key] is String(value) else {
      fail("missing payload")
    }
    fields[key] = Json(value + " ")
    try @mtyuejian.verify_delivery(envelope.stringify()) catch {
      _ => ()
    } noraise {
      _ => fail("modified delivery accepted")
    }
  }
}

///|
test "delivery views cannot mutate saved state" {
  let saved = delivery("1.0.0")
  let before = saved.to_json().stringify()
  if saved.to_json() is Object(fields) {
    fields["report"] = Json("{}")
  }
  assert_eq(saved.to_json().stringify(), before)
  assert_eq(@mtyuejian.verify_delivery(before).assessment().exit_code(), 1)
}

///|
test "a failed verification does not prevent later recovery" {
  let saved = delivery("1.0.0").to_json().stringify()
  try @mtyuejian.verify_delivery(saved + " null") catch {
    _ => ()
  } noraise {
    _ => fail("trailing content accepted")
  }
  assert_eq(@mtyuejian.verify_delivery(saved).assessment().exit_code(), 1)
}

///|
test "delivery normalizes caller ordering and binds origins" {
  let raw = sample(semver("[{\"introduced\":\"0\"}]"))
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
  let snap = @mtyuejian.Snapshot::new([
    @mtyuejian.read_advisory(raw, origin="甲"),
  ])
  assert_eq(
    @mtyuejian.capture(snap, [a, b]).digest(),
    @mtyuejian.capture(snap, [b, a]).digest(),
  )
  let other = @mtyuejian.Snapshot::new([
    @mtyuejian.read_advisory(raw, origin="乙"),
  ])
  assert_not_eq(
    @mtyuejian.capture(snap, [a, b]).digest(),
    @mtyuejian.capture(other, [a, b]).digest(),
  )
}
