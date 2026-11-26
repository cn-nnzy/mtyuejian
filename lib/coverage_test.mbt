///|
test "coverage counts installations once across multiple source records" {
  let raw = sample(semver("[{\"introduced\":\"0\"},{\"fixed\":\"2.0.0\"}]"))
  let snapshot = @mtyuejian.Snapshot::new([
    @mtyuejian.read_advisory(raw),
    @mtyuejian.read_advisory(raw.replace(old="x_TEST-1", new="x_TEST-2")),
  ])
  let make = fn(id : String, name : String, version : String) raise {
    @mtyuejian.Package::new(id~, ecosystem="example", name~, version~)
  }
  let items = [
    make("hit", "demo", "1.0.0"),
    make("fixed", "demo", "2.0.0"),
    make("unknown", "other", "1.0.0"),
  ]
  let result = @mtyuejian.assess(snapshot, items)
  let view = result.coverage()
  guard view
    is {
      "exit_code": 1,
      "counts": {
        "resolved_packages": 3,
        "decision_rows": 5,
        "known_match_packages": 1,
        "not_matched_packages": 1,
        "no_advisory_packages": 1,
        "undetermined_packages": 0,
        "packages_with_incomplete_evidence": 1,
        ..
      },
      "diagnostics": Array(
        [
          {
            "category": "missing_advisory",
            "source": { "path": Null, .. },
            "next_action": String(action),
            ..
          },
        ],
      ),
      ..
    } else {
    fail("Package and decision counts were conflated")
  }
  assert_true(!action.is_empty())
  assert_eq(
    @mtyuejian.assess(snapshot, [items[2], items[1], items[0]])
    .coverage()
    .stringify(),
    view.stringify(),
  )
}

///|
test "known matches retain independent incomplete coverage and actionable source pointers" {
  let raw = sample(
    "[{\"type\":\"SEMVER\",\"events\":[{\"introduced\":\"0\"}]},{\"type\":\"ECOSYSTEM\",\"events\":[{\"introduced\":\"0\"}]}]",
  )
  let result = evaluate(raw, "1.0.0")
  guard result.coverage()
    is {
      "counts": {
        "known_match_packages": 1,
        "packages_with_incomplete_evidence": 1,
        ..
      },
      "diagnostics": Array(
        [
          {
            "category": "unsupported_version_rule",
            "code": "unsupported-range",
            "source": {
              "path": "/affected/0/ranges/1",
              "advisory": "x_TEST-1",
              ..
            },
            "report_pointer": "/decisions/0/evidence/1",
            ..
          },
        ],
      ),
      ..
    } else {
    fail("A positive decision hid its unsupported source")
  }
  assert_eq(result.exit_code(), 1)
}

///|
test "withdrawal missing evidence and version syntax have different next steps" {
  let cases = [
    (
      sample("[]").replace(
        old="\"modified\":",
        new="\"withdrawn\":\"2026-11-20T00:00:00Z\",\"modified\":",
      ),
      "1.0.0",
      "withdrawn_advisory",
    ),
    (sample("[]"), "1.0.0", "missing_version_evidence"),
    (sample(semver("[{\"introduced\":\"0\"}]")), "v1.0.0", "version_syntax"),
  ]
  for (raw, version, category) in cases {
    guard evaluate(raw, version).coverage()
      is {
        "exit_code": 3,
        "counts": { "undetermined_packages": 1, .. },
        "diagnostics": Array(
          [{ "category": String(actual), "next_action": String(action), .. }],
        ),
        ..
      } else {
      fail("Incomplete source has no diagnostic")
    }
    assert_eq(actual, category)
    assert_true(!action.is_empty())
  }
}

///|
test "active unscoped advisory entries are diagnosed even beside a negative package" {
  let raw = sample(semver("[{\"introduced\":\"0\"},{\"fixed\":\"1.0.0\"}]")).replace(
    old="\"affected\":[",
    new="\"affected\":[{\"ranges\":[]},",
  )
  guard evaluate(raw, "2.0.0").coverage()
    is {
      "exit_code": 3,
      "counts": {
        "not_matched_packages": 1,
        "unscoped_advisory_entries": 1,
        ..
      },
      "diagnostics": Array(
        [
          {
            "code": "package-identity-missing",
            "source": { "path": "/affected/0", .. },
            ..
          },
        ],
      ),
      ..
    } else {
    fail("Unscoped evidence disappeared")
  }
}

///|
test "file subjects stay unresolved with a distinct artifact diagnostic" {
  let raw = bom(component("a", "2.0.0")).replace(
    old="\"components\":",
    new="\"metadata\":{\"component\":{\"bom-ref\":\"root\",\"type\":\"file\",\"name\":\"project\"}},\"components\":",
  )
  let receipt = bom_delivery(raw)
  let saved = receipt.to_json().stringify()
  let result = receipt.assessment()
  guard result.coverage()
    is {
      "exit_code": 3,
      "counts": {
        "resolved_packages": 1,
        "not_matched_packages": 1,
        "unresolved_entries": 1,
        ..
      },
      "diagnostics": Array(
        [
          {
            "category": "artifact_node",
            "component_kind": "file",
            "source": {
              "path": "/metadata/component",
              "role": "bom_subject",
              ..
            },
            ..
          },
        ],
      ),
      ..
    } else {
    fail("Artifact subject was discarded or treated as an assessable package")
  }
  assert_eq(receipt.to_json().stringify(), saved)
  assert_eq(
    @mtyuejian.verify_bom_delivery(saved).assessment().coverage().stringify(),
    result.coverage().stringify(),
  )
}

///|
test "SPDX FILE purpose is diagnostic metadata without a new admission requirement" {
  let raw = spdx(
    "{\"SPDXID\":\"SPDXRef-root\",\"name\":\"project\",\"primaryPackagePurpose\":\"FILE\"}",
  )
  let result = bom_delivery(raw).assessment()
  guard result.coverage()
    is {
      "exit_code": 3,
      "diagnostics": Array(
        [
          {
            "category": "artifact_node",
            "code": "missing-purl",
            "component_kind": "FILE",
            ..
          },
        ],
      ),
      ..
    } else {
    fail("SPDX artifact not identified")
  }
  let future = raw.replace(old="\"FILE\"", new="{\"future\":true}")
  assert_eq(bom_delivery(future).assessment().exit_code(), 3)
}

///|
test "identity conflicts unsupported identities and external inventories stay distinct" {
  let conflict = component("conflict", "1.0.0").replace(
    old="\"name\":\"demo\"",
    new="\"name\":\"other\"",
  )
  let unsupported = component("npm", "1.0.0").replace(
    old="pkg:cargo",
    new="pkg:npm",
  )
  guard bom_delivery(bom(conflict + "," + unsupported)).assessment().coverage()
    is {
      "counts": { "resolved_packages": 0, "unresolved_entries": 2, .. },
      "diagnostic_counts": {
        "identity_conflict": 1,
        "unsupported_identity": 1,
        ..
      },
      ..
    } else {
    fail("Identity diagnostics conflated")
  }
  let external = spdx(spdx_package("SPDXRef-a", "2.0.0")).replace(
    old="\"packages\":",
    new="\"externalDocumentRefs\":[{\"externalDocumentId\":\"DocumentRef-other\"}],\"packages\":",
  )
  guard bom_delivery(external).assessment().coverage()
    is {
      "exit_code": 3,
      "diagnostics": Array(
        [
          {
            "category": "external_inventory",
            "source": {
              "path": "/externalDocumentRefs/0",
              "role": "external_document",
              ..
            },
            ..
          },
        ],
      ),
      ..
    } else {
    fail("External document silently omitted")
  }
}

///|
test "empty BOM placeholders are entries rather than invented component counts" {
  for raw in [bom(""), spdx("")] {
    guard bom_delivery(raw).assessment().coverage()
      is {
        "exit_code": 3,
        "counts": { "resolved_packages": 0, "unresolved_entries": 1, .. },
        "diagnostic_counts": { "empty_inventory": 1, .. },
        ..
      } else {
      fail("Empty inventory passed or counted an invented package")
    }
  }
}

///|
test "coverage views are independent and do not mutate reports or receipts" {
  let result = evaluate(sample("[]"), "1.0.0")
  let original = result.to_json().stringify()
  let view = result.coverage()
  let expected = view.stringify()
  if view is Object(fields) {
    fields["counts"] = Json::null()
  }
  assert_eq(result.coverage().stringify(), expected)
  assert_eq(result.to_json().stringify(), original)
  let receipt = bom_delivery(bom("{}"))
  let text = receipt.to_json().stringify()
  receipt.assessment().coverage() |> ignore
  assert_eq(receipt.to_json().stringify(), text)
  assert_true(receipt.to_markdown().contains("Coverage and next steps"))
}
