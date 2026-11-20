///|
fn alias_doc(
  id : String,
  aliases : Array[String],
  ranges~ : String = "[{\"type\":\"SEMVER\",\"events\":[{\"introduced\":\"0\"}]}]",
) -> String {
  sample(ranges).replace(
    old="\"id\":\"x_TEST-1\"",
    new="\"id\":" +
      Json(id).stringify() +
      ",\"aliases\":" +
      Json(aliases).stringify(),
  )
}

///|
fn alias_receipt(docs : Array[String]) -> @mtyuejian.Delivery raise {
  @mtyuejian.capture(
    @mtyuejian.Snapshot::new(docs.map(raw => @mtyuejian.read_advisory(raw))),
    [
      @mtyuejian.Package::new(
        id="test",
        ecosystem="example",
        name="demo",
        version="1.0.0",
      ),
    ],
  )
}

///|
fn assert_review_partition(view : Json) -> Unit raise {
  guard view
    is {
      "groups": Array(groups),
      "unassigned_decision_indices": Array(unassigned),
      "report": { "decisions": Array(decisions), .. },
      ..
    } else {
    fail("missing review partition")
  }
  let seen : Map[String, Unit] = Map([])
  let indices = unassigned.copy()
  for group in groups {
    guard group is { "decision_indices": Array(rows), .. } else {
      fail("missing indices")
    }
    indices.append(rows)
  }
  for index in indices {
    let key = index.stringify()
    assert_true(!seen.contains(key))
    seen[key] = ()
  }
  assert_eq(seen.length(), decisions.length())
  for i in 0..<decisions.length() {
    assert_true(seen.contains(Json(i).stringify()))
  }
}

///|
test "declared identifier links form deterministic transitive source groups" {
  let receipt = alias_receipt([
    alias_doc("x_ALPHA-1", ["SHARED-1"]),
    alias_doc("x_BETA-1", ["SHARED-2"]),
    alias_doc("x_GAMMA-1", ["SHARED-1", "SHARED-2"]),
    alias_doc("x_ZETA-1", []),
  ])
  let view = receipt.alias_review()
  guard view is { "groups": Array([first, second]), .. } &&
    first
    is {
      "records": Array([_, _, _]),
      "links": Array([_, _]),
      "decision_indices": Array([0, 1, 2]),
      ..
    } &&
    second is { "decision_indices": Array([3]), .. } else {
    fail("transitive links or singleton lost")
  }
  assert_review_partition(view)
  assert_eq(receipt.assessment().outcomes().length(), 4)
}

///|
test "self and repeated aliases do not fabricate shared-source counts" {
  let view = alias_receipt([
    alias_doc("x_ALPHA-1", ["x_ALPHA-1", "SHARED-1", "SHARED-1"]),
    alias_doc("x_BETA-1", ["SHARED-1"]),
  ]).alias_review()
  guard view
    is {
      "groups": Array(
        [
          {
            "links": Array(
              [
                {
                  "identifier": "SHARED-1",
                  "record_indices": Array([0, 1]),
                  ..
                },
              ],
            ),
            ..
          },
        ],
      ),
      ..
    } else {
    fail("duplicate aliases counted as extra records")
  }
  assert_review_partition(view)
}

///|
test "a primary ID named as another source alias establishes a visible link" {
  let view = alias_receipt([
    alias_doc("x_ALPHA-1", ["x_BETA-1"]),
    alias_doc("x_BETA-1", []),
  ]).alias_review()
  guard view
    is {
      "groups": Array(
        [
          {
            "records": Array([_, _]),
            "links": Array([{ "identifier": "x_BETA-1", .. }]),
            ..
          },
        ],
      ),
      ..
    } else {
    fail("primary identifier link omitted")
  }
  assert_review_partition(view)
}

///|
test "alias grouping never merges positive withdrawn or unsupported decisions" {
  let withdrawn = alias_doc("x_BETA-1", ["SHARED-1"]).replace(
    old="\"modified\":",
    new="\"withdrawn\":\"2026-11-19T01:00:00Z\",\"modified\":",
  )
  let unknown = alias_doc(
    "x_GAMMA-1",
    ["SHARED-1"],
    ranges="[{\"type\":\"ECOSYSTEM\",\"events\":[{\"introduced\":\"0\"}]}]",
  )
  let receipt = alias_receipt([
    alias_doc("x_ALPHA-1", ["SHARED-1"]),
    withdrawn,
    unknown,
  ])
  assert_eq(receipt.assessment().outcomes(), [
    @mtyuejian.Affected,
    @mtyuejian.Withdrawn,
    @mtyuejian.Undetermined,
  ])
  let view = receipt.alias_review()
  guard view
    is {
      "exit_code": 1,
      "groups": Array(
        [
          {
            "has_known_match": true,
            "has_incomplete_evidence": true,
            "decision_indices": Array([0, 1, 2]),
            ..
          },
        ],
      ),
      ..
    } else {
    fail("source disagreement collapsed")
  }
  assert_review_partition(view)
}

///|
test "no-advisory decisions and active unscoped entries remain visible" {
  let raw = alias_doc("x_ALPHA-1", []).replace(
    old="\"affected\":[",
    new="\"affected\":[{\"ranges\":[]},",
  )
  let receipt = @mtyuejian.capture(
    @mtyuejian.Snapshot::new([@mtyuejian.read_advisory(raw)]),
    [
      @mtyuejian.Package::new(
        id="other",
        ecosystem="unrelated",
        name="other",
        version="1.0.0",
      ),
    ],
  )
  let view = receipt.alias_review()
  guard view
    is {
      "exit_code": 3,
      "unassigned_decision_indices": Array([0]),
      "groups": Array(
        [
          {
            "has_scoped_decisions": false,
            "has_incomplete_evidence": true,
            "unscoped_entries": Array(
              [{ "record_index": 0, "path": "/affected/0", .. }],
            ),
            ..
          },
        ],
      ),
      ..
    } else {
    fail("unassigned or unscoped evidence lost")
  }
  assert_review_partition(view)
}

///|
test "empty BOM review retains dataset identifiers and original outer evidence" {
  let snap = @mtyuejian.Snapshot::new([
    @mtyuejian.read_advisory(alias_doc("x_ALPHA-1", ["SHARED-1"])),
  ])
  let receipt = @mtyuejian.capture_bom(snap, @mtyuejian.read_bom(bom("")))
  guard receipt.alias_review()
    is {
      "exit_code": 3,
      "assessment_pointer": "/assessment",
      "groups": Array(
        [{ "records": Array([_]), "decision_indices": Array([]), .. }],
      ),
      "report": {
        "assessment": Null,
        "import": { "unresolved": Array([_]), .. },
        ..
      },
      ..
    } else {
    fail("unresolved-only BOM disappeared")
  }
}

///|
test "case differences and related metadata do not invent alias equivalence" {
  let related = alias_doc("x_GAMMA-1", []).replace(
    old="\"affected\":",
    new="\"related\":[\"x_ALPHA-1\"],\"affected\":",
  )
  let view = alias_receipt([
    alias_doc("x_ALPHA-1", ["SHARED-1"]),
    alias_doc("x_BETA-1", ["shared-1"]),
    related,
  ]).alias_review()
  guard view is { "groups": Array(groups), .. } else { fail("missing groups") }
  assert_eq(groups.length(), 3)
  assert_review_partition(view)
}

///|
test "alias review is stable after snapshot reordering replay and view mutation" {
  let a = alias_doc("x_ALPHA-1", ["SHARED-1"])
  let b = alias_doc("x_BETA-1", ["SHARED-1"])
  let receipt = alias_receipt([a, b])
  let expected = receipt.alias_review().stringify()
  assert_eq(alias_receipt([b, a]).alias_review().stringify(), expected)
  assert_eq(
    @mtyuejian.verify_delivery(receipt.to_json().stringify())
    .alias_review()
    .stringify(),
    expected,
  )
  if receipt.alias_review() is Object(fields) {
    fields["report"] = Json::null()
  }
  assert_eq(receipt.alias_review().stringify(), expected)
}

///|
test "maximum source and alias counts use index links without repeating long IDs" {
  let aliases = Array::makei(128, i => "SHARED-" + i.to_string())
  let docs = Array::makei(64, i => {
    alias_doc("x_RECORD-" + i.to_string(), aliases)
  })
  let view = alias_receipt(docs).alias_review()
  guard view
    is {
      "groups": Array(
        [{ "records": Array(records), "links": Array(links), .. }],
      ),
      ..
    } else {
    fail("maximum grouping failed")
  }
  assert_eq(records.length(), 64)
  assert_eq(links.length(), 128)
  for link in links {
    guard link is { "record_indices": Array(indices), .. } else {
      fail("missing link")
    }
    assert_eq(indices.length(), 64)
  }
  assert_review_partition(view)
}
