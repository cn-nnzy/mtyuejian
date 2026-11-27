///|
// Park–Miller with a wide intermediate. Every backend generates the same cases.
fn next_case(seed : Ref[Int64], bound : Int32) -> Int32 {
  seed.val = seed.val * 48271L % 2147483647L
  seed.val.to_int() % bound
}

///|
fn reject_generated_bom(raw : String, label : String) -> Unit raise {
  try @mtyuejian.read_bom(raw) catch {
    @mtyuejian.Invalid(code~, ..) => assert_true(!code.is_empty())
  } noraise {
    _ => fail("Malformed BOM admitted (\{label}): \{Repr(raw)}")
  }
}

///|
test "generated JSON mutations reject with typed errors and recover with exact bytes" {
  let seed = Ref(612712L)
  for i in 0..<48 {
    let padding = Array::makei(3 + next_case(seed, 30), _ => {
      ["a", "\\", "/", "\"", "\r\n", "😀", "~"][next_case(seed, 7)]
    }).join("")
    let raw = bom(
      component("instance-\{i}", "2.0.0"),
      version=["1.5", "1.6", "1.7"][i % 3],
    ).replace(
      old="\"components\":",
      new="\"opaque\":" + Json(padding).stringify() + ",\"components\":",
    )
    let label = "seed=612712 case=\{i}"
    let cut = next_case(seed, raw.length())
    reject_generated_bom(raw[0:cut].to_owned(), label + " truncated")
    reject_generated_bom(raw + "null", label + " trailing token")
    reject_generated_bom(
      raw.replace(
        old="\"components\":",
        new="\"compo\\u006eents\":[],\"components\":",
      ),
      label + " escaped duplicate",
    )
    reject_generated_bom(
      raw.replace(old="\"opaque\":", new="\"bad\":\"\\uD800\",\"opaque\":"),
      label + " isolated surrogate",
    )
    let normal = @mtyuejian.read_bom(raw)
    assert_eq(normal.source(), raw)
    assert_eq(normal.assess(cargo_snapshot()).exit_code(), 0)
  }
}

///|
// Model the generated versions with integer ranks. Each patch has four
// prereleases followed by the final release. Build metadata never changes rank.
fn generated_version(rank : Int32, build : Bool) -> String {
  let patch = rank / 5
  let suffix = match rank % 5 {
    4 => ""
    pre => "-rc.\{pre}"
  }
  "1.0.\{patch}" + suffix + (if build { "+test.4" } else { "" })
}

///|
test "generated ranges agree with integer interval model under event permutations" {
  let seed = Ref(41193L)
  for i in 0..<96 {
    let lo = next_case(seed, 20)
    let hi = lo + 1 + next_case(seed, 12)
    let limit = lo + 1 + next_case(seed, 20)
    let closed = i % 2 == 0
    let open_event : Json = { "introduced": Json(generated_version(lo, false)) }
    let close_key = if closed { "last_affected" } else { "fixed" }
    let close_event = Json::object(
      Map([(close_key, Json(generated_version(hi, true)))]),
    )
    let cap : Json = { "limit": Json(generated_version(limit, false)) }
    let ordered = Json([open_event, close_event, cap]).stringify()
    let shuffled = Json([cap, close_event, open_event]).stringify()
    let legacy = crate_snapshot(semver(ordered))
    let selected = crate_snapshot(crate_range(shuffled)).with_crates_io()
    let encoded = selected.to_json().stringify()
    let replayed = @mtyuejian.read_snapshot(encoded)
    assert_eq(replayed.to_json().stringify(), encoded)
    for
      rank in [
        lo - 1,
        lo,
        hi - 1,
        hi,
        hi + 1,
        limit - 1,
        limit,
        next_case(seed, 36),
      ] {
      if rank < 0 {
        continue
      }
      let expected = if rank >= lo &&
        (rank < hi || (closed && rank == hi)) &&
        rank < limit {
        @mtyuejian.Affected
      } else {
        @mtyuejian.NotMatched
      }
      let version = generated_version(rank, next_case(seed, 2) == 1)
      for snapshot in [legacy, selected, replayed] {
        let actual = crate_outcome(snapshot, version)
        guard actual == expected else {
          fail(
            "seed=41193 case=\{i} lo=\{lo} hi=\{hi} limit=\{limit} closed=\{closed} query=\{version}: expected \{Repr(expected)}, got \{Repr(actual)}",
          )
        }
      }
    }
  }
}

///|
test "generated mixed inventories retain every node and reproduce pinned receipts" {
  let seed = Ref(638103L)
  let snapshot = cargo_snapshot()
  for i in 0..<48 {
    let count = 1 + next_case(seed, 16)
    let cdx = []
    let spdx_rows = []
    let mut resolved = 0
    let mut affected = 0
    for j in 0..<count {
      let id = "SPDXRef-\{i}-\{j}"
      let kind = next_case(seed, 5)
      let version = if kind == 0 { "1.0.0" } else { "2.0.0" }
      let c = component(id, version)
      let s = spdx_package(id, version)
      if kind <= 1 {
        resolved += 1
        if kind == 0 {
          affected += 1
        }
        cdx.push(c)
        spdx_rows.push(s)
      } else if kind == 2 {
        cdx.push(c.replace(old="pkg:cargo", new="pkg:npm"))
        spdx_rows.push(s.replace(old="pkg:cargo", new="pkg:npm"))
      } else if kind == 3 {
        cdx.push(c.replace(old="\"name\":\"demo\"", new="\"name\":\"\""))
        spdx_rows.push(s.replace(old="\"name\":\"demo\"", new="\"name\":\"\""))
      } else {
        cdx.push(c.replace(old="pkg:cargo/demo@", new="pkg:cargo/unrelated@"))
        spdx_rows.push(
          s.replace(old="pkg:cargo/demo@", new="pkg:cargo/unrelated@"),
        )
      }
    }
    let expected = if affected > 0 {
      1
    } else if resolved < count {
      3
    } else {
      0
    }
    for raw in [bom(cdx.join(","), version="1.7"), spdx(spdx_rows.join(","))] {
      let imported = @mtyuejian.read_bom(raw, origin="seed=638103 case=\{i}")
      let saved = @mtyuejian.capture_bom(snapshot, imported)
      let encoded = saved.to_json().stringify()
      let replayed = @mtyuejian.verify_bom_delivery(
        encoded,
        expected_sha256=saved.digest(),
      )
      guard replayed.to_json().stringify() == encoded &&
        imported.source() == raw &&
        replayed.assessment().exit_code() == expected &&
        replayed.assessment().to_json()
        is {
          "import": {
            "packages": Array(packages),
            "unresolved": Array(unresolved),
            ..
          },
          ..
        } &&
        packages.length() == resolved &&
        unresolved.length() == count - resolved else {
        fail(
          "seed=638103 case=\{i} resolved=\{resolved} count=\{count} gate=\{expected}: \{raw}",
        )
      }
      assert_eq(
        @mtyuejian.capture_bom(snapshot, imported).to_json().stringify(),
        encoded,
      )
    }
  }
}
