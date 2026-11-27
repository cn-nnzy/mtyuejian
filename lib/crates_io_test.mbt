///|
fn crate_snapshot(
  ranges : String,
  ecosystem~ : String = "crates.io",
) -> @mtyuejian.Snapshot raise {
  @mtyuejian.Snapshot::new([
    @mtyuejian.read_advisory(
      sample(ranges).replace(old="example", new=ecosystem),
    ),
  ])
}

///|
fn crate_item(
  version : String,
  ecosystem~ : String = "crates.io",
) -> @mtyuejian.Package raise {
  @mtyuejian.Package::new(id="test", ecosystem~, name="demo", version~)
}

///|
fn crate_range(events : String) -> String {
  "[{\"type\":\"ECOSYSTEM\",\"events\":" + events + "}]"
}

///|
fn crate_outcome(
  snapshot : @mtyuejian.Snapshot,
  version : String,
) -> @mtyuejian.Outcome raise {
  @mtyuejian.assess(snapshot, [crate_item(version)]).outcomes()[0]
}

///|
test "crates ECOSYSTEM ordering is explicit and does not mutate legacy evidence" {
  let legacy = crate_snapshot(
    crate_range("[{\"introduced\":\"0\"},{\"fixed\":\"1.2.0\"}]"),
  )
  let original = legacy.to_json().stringify()
  let selected = legacy.with_crates_io()
  assert_eq(crate_outcome(legacy, "1.1.0"), @mtyuejian.Undetermined)
  assert_eq(crate_outcome(selected, "1.1.0"), @mtyuejian.Affected)
  assert_eq(crate_outcome(selected, "1.2.0"), @mtyuejian.NotMatched)
  assert_eq(legacy.to_json().stringify(), original)
  assert_eq(
    selected.with_crates_io().to_json().stringify(),
    selected.to_json().stringify(),
  )
  guard selected.to_json()
    is { "schema_version": 2, "evaluation_profile": "crates-io-semver-v1", .. } else {
    fail("Evaluation semantics are not bound to the snapshot")
  }
}

///|
test "crate prereleases use precedence and build metadata does not change a boundary" {
  let snapshot = crate_snapshot(
    crate_range("[{\"introduced\":\"1.0.0-alpha.2\"},{\"fixed\":\"1.0.0\"}]"),
  ).with_crates_io()
  for
    version in [
      "1.0.0-alpha.2", "1.0.0-alpha.10", "1.0.0-beta", "1.0.0-rc.1+build.9",
    ] {
    assert_eq(crate_outcome(snapshot, version), @mtyuejian.Affected)
  }
  for version in ["1.0.0-alpha.1", "1.0.0", "1.0.0+build.1"] {
    assert_eq(crate_outcome(snapshot, version), @mtyuejian.NotMatched)
  }
}

///|
test "multiple unsorted intervals preserve source event positions and inclusive boundaries" {
  let snapshot = crate_snapshot(
    crate_range(
      "[{\"fixed\":\"2.0.0\"},{\"introduced\":\"3.0.0\"},{\"introduced\":\"0\"},{\"last_affected\":\"3.0.0+build\"}]",
    ),
  ).with_crates_io()
  assert_eq(crate_outcome(snapshot, "0.0.0-0"), @mtyuejian.Affected)
  assert_eq(crate_outcome(snapshot, "2.0.0"), @mtyuejian.NotMatched)
  assert_eq(crate_outcome(snapshot, "3.0.0"), @mtyuejian.Affected)
  assert_eq(crate_outcome(snapshot, "3.0.1"), @mtyuejian.NotMatched)
  guard @mtyuejian.assess(snapshot, [crate_item("1.0.0")]).to_json()
    is {
      "decisions": Array(
        [
          {
            "evidence": Array(
              [
                {
                  "code": "crates-io-interval",
                  "event_indices": Array([2, 0]),
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
    fail("Source indices were rewritten")
  }
}

///|
test "limits keep their OR semantics and star is an unbounded limit" {
  let limited = crate_snapshot(
    crate_range(
      "[{\"introduced\":\"0\"},{\"limit\":\"1.0.0\"},{\"limit\":\"2.0.0\"}]",
    ),
  ).with_crates_io()
  assert_eq(crate_outcome(limited, "1.5.0"), @mtyuejian.Affected)
  assert_eq(crate_outcome(limited, "2.0.0"), @mtyuejian.NotMatched)
  let unlimited = crate_snapshot(
    crate_range("[{\"introduced\":\"0\"},{\"limit\":\"*\"}]"),
  ).with_crates_io()
  assert_eq(
    crate_outcome(unlimited, "18446744073709551615.0.0"),
    @mtyuejian.Affected,
  )
}

///|
test "u64 core overflow and noncanonical crate spellings stay undetermined" {
  let snapshot = crate_snapshot(crate_range("[{\"introduced\":\"0\"}]")).with_crates_io()
  for
    version in [
      "18446744073709551616.0.0",
      "1.18446744073709551616.0",
      "v1.0.0",
      "1.0",
      "01.0.0",
      "1.0.0-01",
      "1.0.0 ",
      "1.0.0+",
      "1.0.0-" + "x".repeat(251),
    ] {
    let result = @mtyuejian.assess(snapshot, [crate_item(version)])
    assert_eq(result.exit_code(), 3)
    guard result.coverage()
      is {
        "diagnostics": Array([{ "code": "query-is-not-crates-version", .. }]),
        ..
      } else {
      fail("Invalid crate version was coerced")
    }
  }
  assert_eq(
    crate_outcome(snapshot, "1.0.0-" + "x".repeat(250)),
    @mtyuejian.Affected,
  )
}

///|
test "malformed supported ranges reject clearly and leave the original snapshot usable" {
  for
    events in [
      "[null]", "[{\"introduced\":\"v1.0.0\"}]", "[{\"introduced\":\"18446744073709551616.0.0\"}]",
      "[{\"introduced\":\"0\",\"fixed\":\"1.0.0\"}]", "[{\"introduced\":\"0\"},{\"future_event\":\"1.0.0\"}]",
      "[{\"introduced\":\"1.0.0\"},{\"fixed\":\"1.0.0+build\"}]",
    ] {
    let snapshot = crate_snapshot(crate_range(events))
    try snapshot.with_crates_io() catch {
      _ => ()
    } noraise {
      _ => fail("Unsupported crates range accepted")
    }
    assert_eq(crate_outcome(snapshot, "1.0.0"), @mtyuejian.Undetermined)
  }
}

///|
test "other ecosystems and Git ranges are not promoted to crates semantics" {
  for ecosystem in ["npm", "Crates.io", "crates.io:custom"] {
    let snapshot = crate_snapshot(crate_range("[null]"), ecosystem~).with_crates_io()
    assert_eq(
      @mtyuejian.assess(snapshot, [crate_item("1.0.0", ecosystem~)]).outcomes(),
      [@mtyuejian.Undetermined],
    )
  }
  let snapshot = crate_snapshot(
    "[{\"type\":\"ECOSYSTEM\",\"events\":[{\"introduced\":\"0\"}]},{\"type\":\"GIT\",\"repo\":\"https://example.invalid/repo\",\"events\":[{}]}]",
  ).with_crates_io()
  let result = @mtyuejian.assess(snapshot, [crate_item("1.0.0")])
  assert_eq(result.exit_code(), 1)
  guard result.to_json()
    is { "decisions": Array([{ "incomplete": true, .. }]), .. } else {
    fail("A known match hid Git uncertainty")
  }
}

///|
test "schema two snapshots preserve raw metadata and reject unknown profile selectors" {
  let raw = sample(crate_range("[{\"introduced\":\"0\"}]"))
    .replace(old="example", new="crates.io")
    .replace(
      old="\"affected\":",
      new="\"future\":900719925474099312345e9999,\"affected\":",
    )
  let snapshot = @mtyuejian.Snapshot::new([
    @mtyuejian.read_advisory(raw, origin="archive"),
  ]).with_crates_io()
  let text = snapshot.to_json().stringify()
  assert_eq(@mtyuejian.read_snapshot(text).to_json().stringify(), text)
  guard snapshot.to_json()
    is { "documents": Array([{ "text": String(retained), .. }]), .. } else {
    fail("Original source missing")
  }
  assert_eq(retained, raw)
  for
    invalid in [
      text.replace(old="crates-io-semver-v1", new="unknown-v1"),
      text.replace(old="\"documents\":", new="\"typo\":true,\"documents\":"),
      text.replace(old="\"schema_version\":2", new="\"schema_version\":1"),
    ] {
    try @mtyuejian.read_snapshot(invalid) catch {
      _ => ()
    } noraise {
      _ => fail("Ambiguous snapshot semantics accepted")
    }
  }
}

///|
test "receipt digests bind evaluation semantics and replay reconstructs the selected rules" {
  let legacy = crate_snapshot(
    crate_range("[{\"introduced\":\"0\"},{\"fixed\":\"2.0.0\"}]"),
  )
  let before = @mtyuejian.capture(legacy, [crate_item("2.0.0")])
  let selected = @mtyuejian.capture(legacy.with_crates_io(), [
    crate_item("2.0.0"),
  ])
  assert_eq(
    @mtyuejian.verify_delivery(before.to_json().stringify())
    .assessment()
    .exit_code(),
    3,
  )
  assert_eq(
    @mtyuejian.verify_delivery(
      selected.to_json().stringify(),
      expected_sha256=selected.digest(),
    )
    .assessment()
    .exit_code(),
    0,
  )
  assert_true(before.digest() != selected.digest())
  let changed = selected.to_json()
  if changed is Object(fields) {
    fields["snapshot"] = Json(legacy.to_json().stringify())
  }
  try @mtyuejian.verify_delivery(changed.stringify()) catch {
    _ => ()
  } noraise {
    _ => fail("Changed evaluation semantics kept an approved digest")
  }
  assert_eq(
    @mtyuejian.verify_delivery(selected.to_json().stringify()).digest(),
    selected.digest(),
  )
}

///|
test "BOM replay keeps unsupported nodes and exports the new snapshot through review formats" {
  let snapshot = crate_snapshot(
    crate_range("[{\"introduced\":\"0\"},{\"fixed\":\"2.0.0\"}]"),
  )
  let raw = bom(
    component("a", "1.0.0") +
    ",{\"bom-ref\":\"file\",\"type\":\"file\",\"name\":\"Cargo.lock\"}",
  )
  let captured = @mtyuejian.capture_bom(
    snapshot.with_crates_io(),
    @mtyuejian.read_bom(raw),
  )
  let restored = @mtyuejian.verify_bom_delivery(captured.to_json().stringify())
  assert_eq(restored.digest(), captured.digest())
  assert_eq(restored.assessment().exit_code(), 1)
  guard restored.assessment().to_json()
    is {
      "evaluation_profile": "crates-io-semver-v1",
      "import": { "unresolved": Array([_]), .. },
      ..
    } else {
    fail("BOM completeness or evaluation context lost")
  }
  restored.assessment().to_sarif(bom_uri="bom.json", locate=true) |> ignore
  assert_true(restored.to_markdown().contains("crates-io-semver-v1"))
}

///|
test "profile changes alone block a delta but stable selected profiles remain comparable" {
  let snapshot = crate_snapshot(
    semver("[{\"introduced\":\"0\"},{\"fixed\":\"1.0.0\"}]"),
  )
  let old = @mtyuejian.capture(snapshot, [crate_item("2.0.0")])
  let current = @mtyuejian.capture(snapshot.with_crates_io(), [
    crate_item("2.0.0"),
  ])
  assert_eq(@mtyuejian.compare_deliveries(old, current).exit_code(), 3)
  assert_eq(@mtyuejian.compare_deliveries(current, current).exit_code(), 0)
  guard @mtyuejian.compare_deliveries(old, current).to_json()
    is { "evaluation_profile_changed": true, .. } else {
    fail("Profile transition was hidden")
  }
  let imported = @mtyuejian.read_bom(bom(component("a", "2.0.0")))
  let old_bom = @mtyuejian.capture_bom(snapshot, imported)
  let new_bom = @mtyuejian.capture_bom(snapshot.with_crates_io(), imported)
  assert_eq(@mtyuejian.compare_bom_deliveries(old_bom, new_bom).exit_code(), 3)
  assert_eq(@mtyuejian.compare_bom_deliveries(new_bom, new_bom).exit_code(), 0)
}

///|
test "newly interpretable positive evidence takes precedence over profile-change review" {
  let snapshot = crate_snapshot(crate_range("[{\"introduced\":\"0\"}]"))
  let old = @mtyuejian.capture(snapshot, [crate_item("1.0.0")])
  let current = @mtyuejian.capture(snapshot.with_crates_io(), [
    crate_item("1.0.0"),
  ])
  assert_eq(@mtyuejian.compare_deliveries(old, current).exit_code(), 1)
}
