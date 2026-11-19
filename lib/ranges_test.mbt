///|
fn sample(ranges : String, versions~ : String = "[]") -> String {
  "{\"id\":\"x_TEST-1\",\"modified\":\"2026-11-19T00:00:00Z\",\"affected\":[{\"package\":{\"ecosystem\":\"example\",\"name\":\"demo\"},\"versions\":" +
  versions +
  ",\"ranges\":" +
  ranges +
  "}]}"
}

///|
fn semver(events : String) -> String {
  "[{\"type\":\"SEMVER\",\"events\":" + events + "}]"
}

///|
fn evaluate(input : String, version : String) -> @mtyuejian.Assessment raise {
  let doc = @mtyuejian.read_advisory(input)
  let snapshot = @mtyuejian.Snapshot::new([doc])
  let item = @mtyuejian.Package::new(
    id="test",
    ecosystem="example",
    name="demo",
    version~,
  )
  @mtyuejian.assess(snapshot, [item])
}

///|
fn outcome(input : String, version : String) -> @mtyuejian.Outcome raise {
  evaluate(input, version).outcomes()[0]
}

///|
test "introduced inclusive and fixed exclusive" {
  let doc = sample(semver("[{\"introduced\":\"1.0.0\"},{\"fixed\":\"2.0.0\"}]"))
  assert_eq(outcome(doc, "0.9.9"), @mtyuejian.NotMatched)
  assert_eq(outcome(doc, "1.0.0"), @mtyuejian.Affected)
  assert_eq(outcome(doc, "2.0.0-rc.1"), @mtyuejian.Affected)
  assert_eq(outcome(doc, "2.0.0"), @mtyuejian.NotMatched)
  assert_eq(outcome(doc, "2.0.1"), @mtyuejian.NotMatched)
}

///|
test "last affected includes its boundary and singleton" {
  let doc = sample(
    semver("[{\"introduced\":\"1.0.0\"},{\"last_affected\":\"1.0.0\"}]"),
  )
  assert_eq(outcome(doc, "1.0.0-rc"), @mtyuejian.NotMatched)
  assert_eq(outcome(doc, "1.0.0+build.9"), @mtyuejian.Affected)
  assert_eq(outcome(doc, "1.0.1"), @mtyuejian.NotMatched)
}

///|
test "sentinel zero precedes every valid semver" {
  let doc = sample(semver("[{\"introduced\":\"0\"}]"))
  assert_eq(outcome(doc, "0.0.0-0"), @mtyuejian.Affected)
  assert_eq(
    outcome(doc, "999999999999999999999999999999.0.0"),
    @mtyuejian.Affected,
  )
}

///|
test "disjoint intervals are a union" {
  let doc = sample(
    semver(
      "[{\"introduced\":\"1.0.0\"},{\"fixed\":\"1.1.0\"},{\"introduced\":\"2.0.0\"},{\"fixed\":\"2.1.0\"}]",
    ),
  )
  assert_eq(outcome(doc, "1.0.5"), @mtyuejian.Affected)
  assert_eq(outcome(doc, "1.9.0"), @mtyuejian.NotMatched)
  assert_eq(outcome(doc, "2.0.5"), @mtyuejian.Affected)
}

///|
test "unsorted events retain original evidence indices" {
  let doc = sample(semver("[{\"fixed\":\"2.0.0\"},{\"introduced\":\"1.0.0\"}]"))
  let report = evaluate(doc, "1.2.0").to_json()
  guard report
    is {
      "decisions": Array(
        [{ "evidence": Array([{ "event_indices": Array(indices), .. }]), .. }],
      ),
      ..
    } else {
    fail("missing evidence")
  }
  assert_eq(indices, [Json(1), Json(0)])
}

///|
test "multiple limits use OR and remain exclusive" {
  let doc = sample(
    semver(
      "[{\"introduced\":\"0\"},{\"limit\":\"1.0.0\"},{\"limit\":\"3.0.0\"}]",
    ),
  )
  assert_eq(outcome(doc, "2.0.0"), @mtyuejian.Affected)
  assert_eq(outcome(doc, "3.0.0"), @mtyuejian.NotMatched)
  let infinity = sample(
    semver("[{\"introduced\":\"0\"},{\"limit\":\"1.0.0\"},{\"limit\":\"*\"}]"),
  )
  assert_eq(outcome(infinity, "3.0.0"), @mtyuejian.Affected)
}

///|
test "semver canonical precedence sequence" {
  let sequence = [
    "1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta", "1.0.0-beta.2",
    "1.0.0-beta.11", "1.0.0-rc.1", "1.0.0",
  ]
  for i in 0..<sequence.length() {
    let doc = sample(
      semver("[{\"introduced\":\"0\"},{\"fixed\":\"" + sequence[i] + "\"}]"),
    )
    for j in 0..<sequence.length() {
      let actual = outcome(doc, sequence[j])
      let expected = if j < i {
        @mtyuejian.Affected
      } else {
        @mtyuejian.NotMatched
      }
      if actual != expected {
        fail(
          "SemVer ordering: query=\{sequence[j]}, fixed=\{sequence[i]}, actual=\{Repr(actual)}",
        )
      }
    }
  }
}

///|
test "numeric components have arbitrary precision within input budget" {
  let doc = sample(
    semver("[{\"introduced\":\"0\"},{\"fixed\":\"99999999999999999999.0.0\"}]"),
  )
  assert_eq(outcome(doc, "99999999999999999998.999.999"), @mtyuejian.Affected)
  assert_eq(outcome(doc, "100000000000000000000.0.0"), @mtyuejian.NotMatched)
}

///|
test "enumerated versions are exact strings and union with ranges" {
  let doc = sample(
    semver("[{\"introduced\":\"1.0.0\"},{\"fixed\":\"2.0.0\"}]"),
    versions="[\"3.0.0+special\"]",
  )
  assert_eq(outcome(doc, "3.0.0+special"), @mtyuejian.Affected)
  assert_eq(outcome(doc, "3.0.0+other"), @mtyuejian.NotMatched)
}

///|
test "unknown ranges never become a negative conclusion" {
  let doc = sample(
    "[{\"type\":\"ECOSYSTEM\",\"events\":[{\"introduced\":\"0\"}]}]",
  )
  assert_eq(outcome(doc, "1.0.0"), @mtyuejian.Undetermined)
  assert_eq(evaluate(doc, "1.0.0").exit_code(), 3)
}

///|
test "positive enumeration survives unsupported non-GIT ordering" {
  let doc = sample(
    "[{\"type\":\"ECOSYSTEM\",\"events\":[{\"introduced\":\"0\"}]}]",
    versions="[\"1:2.0-3\"]",
  )
  let report = evaluate(doc, "1:2.0-3")
  assert_eq(report.outcomes(), [@mtyuejian.Affected])
  assert_eq(report.exit_code(), 1)
  guard report.to_json()
    is { "decisions": Array([{ "incomplete": True, .. }]), .. } else {
    fail("unsupported evidence must remain visible")
  }
}

///|
test "GIT tag enumerations are not treated as package versions" {
  let doc = sample(
    "[{\"type\":\"GIT\",\"repo\":\"https://example.invalid/repo\",\"events\":[{\"introduced\":\"0\"}]}]",
    versions="[\"1.0.0\"]",
  )
  assert_eq(outcome(doc, "1.0.0"), @mtyuejian.Undetermined)
}

///|
test "known positive retains unsupported evidence in same entry" {
  let doc = sample(
    "[{\"type\":\"SEMVER\",\"events\":[{\"introduced\":\"0\"}]},{\"type\":\"FUTURE\",\"events\":[{}]}]",
  )
  assert_eq(evaluate(doc, "1.0.0").exit_code(), 1)
  guard evaluate(doc, "1.0.0").to_json()
    is {
      "decisions": Array([{ "incomplete": True, "evidence": Array(items), .. }]),
      ..
    } &&
    items.length() == 2 else {
    fail("incomplete evidence was lost")
  }
}

///|
test "malformed query is unknown rather than coerced" {
  let doc = sample(semver("[{\"introduced\":\"0\"}]"))
  for
    version in [
      "v1.0.0", "1.0", "01.0.0", "1.0.0-01", "1.0.0+", "1.0.0-a..b", "1.0.0+a+b",
      "1.0.0 ",
    ] {
    assert_eq(outcome(doc, version), @mtyuejian.Undetermined)
  }
}

///|
test "property generated integer boundaries match independent arithmetic" {
  for start in 0..<10 {
    for end in (start + 1)..<12 {
      let doc = sample(
        semver(
          "[{\"introduced\":\"1.0." +
          start.to_string() +
          "\"},{\"fixed\":\"1.0." +
          end.to_string() +
          "\"}]",
        ),
      )
      for query in 0..<13 {
        assert_eq(
          outcome(doc, "1.0." + query.to_string()),
          if query >= start && query < end {
            @mtyuejian.Affected
          } else {
            @mtyuejian.NotMatched
          },
        )
      }
    }
  }
}
