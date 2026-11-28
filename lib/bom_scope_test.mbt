///|
test "scope agreement uses exact coordinates across formats despite local ID changes" {
  let left = @mtyuejian.read_bom(bom(component("local-cdx", "2.0.0")))
  let right = @mtyuejian.read_bom(spdx(spdx_package("SPDXRef-local", "2.0.0")))
  let result = @mtyuejian.compare_bom_scope(left, right)
  assert_eq(result.exit_code(), 0)
  guard result.to_json()
    is {
      "left": { "profile": "cyclonedx-cargo-v1", .. },
      "right": { "profile": "spdx-cargo-v1", .. },
      "identities": Array(
        [
          {
            "name": "demo",
            "version": "2.0.0",
            "shared_instances": 1,
            "left_ids": Array(["local-cdx"]),
            "right_ids": Array(["SPDXRef-local"]),
            ..
          },
        ],
      ),
      ..
    } else {
    fail("Cross-format package identity was not reconciled")
  }
}

///|
test "scope comparison accounts for repeats, version differences and unrelated nodes" {
  let left = @mtyuejian.read_bom(
    bom(
      [
        component("z", "1.0.0"),
        component("a", "1.0.0"),
        component("same-id", "2.0.0"),
      ].join(","),
    ),
  )
  let right = @mtyuejian.read_bom(
    bom(
      [
        component("x", "1.0.0"),
        component("same-id", "2.0.0+build"),
        component("unrelated", "1.0.0")
        .replace(old="\"name\":\"demo\"", new="\"name\":\"other\"")
        .replace(old="pkg:cargo/demo@", new="pkg:cargo/other@"),
      ].join(","),
    ),
  )
  let result = @mtyuejian.compare_bom_scope(left, right)
  assert_eq(result.exit_code(), 3)
  guard result.to_json()
    is {
      "counts": {
        "identities": 4,
        "shared_instances": 1,
        "left_only_instances": 2,
        "right_only_instances": 2,
        "repeated_identities": 1,
        ..
      },
      "identities": Array(
        [
          {
            "version": "1.0.0",
            "left_ids": Array(["a", "z"]),
            "right_ids": Array(["x"]),
            "left_only_instances": 1,
            "repeated_identity": true,
            ..
          },
          {
            "version": "2.0.0",
            "left_only_instances": 1,
            "right_ids": Array([]),
            ..
          },
          {
            "version": "2.0.0+build",
            "right_only_instances": 1,
            "left_ids": Array([]),
            ..
          },
          { "name": "other", "right_only_instances": 1, .. },
        ],
      ),
      ..
    } else {
    fail("Unexpected scoped identities: " + result.to_json().stringify())
  }
  let reverse = @mtyuejian.compare_bom_scope(right, left)
  assert_eq(reverse.exit_code(), result.exit_code())
  guard reverse.to_json()
    is {
      "identities": Array(
        [{ "left_ids": Array(["x"]), "right_only_instances": 1, .. }, ..],
      ),
      ..
    } else {
    fail("Swapping inputs must swap their counts and IDs")
  }
}

///|
test "identical unresolved components and external inventories still require review" {
  let raw = spdx(
    spdx_package("SPDXRef-a", "1.0.0") +
    ",{\"SPDXID\":\"SPDXRef-unresolved\",\"name\":\"\"}",
  ).replace(
    old="\"packages\":",
    new="\"externalDocumentRefs\":[{\"externalDocumentId\":\"DocumentRef-dependency\"}],\"packages\":",
  )
  let input = @mtyuejian.read_bom(raw, origin="supplied SPDX")
  let result = @mtyuejian.compare_bom_scope(input, input)
  assert_eq(result.exit_code(), 3)
  let view = result.to_json()
  guard view
    is {
      "left": {
        "origin": "supplied SPDX",
        "source_sha256": String(digest),
        "unresolved": Array(
          [
            { "path": "/packages/1", "code": "missing-purl", .. },
            {
              "path": "/externalDocumentRefs/0",
              "code": "external-document-not-expanded",
              ..
            },
          ],
        ),
        ..
      },
      "right": {
        "source_sha256": String(second),
        "unresolved": Array([_, _]),
        ..
      },
      "counts": {
        "shared_instances": 1,
        "left_only_instances": 0,
        "right_only_instances": 0,
        ..
      },
      ..
    } else {
    fail("Unresolved source positions did not survive comparison")
  }
  assert_eq(digest.length(), 64)
  assert_eq(digest, second)
  let changed = @mtyuejian.read_bom(raw + "\n", origin="supplied SPDX")
  guard @mtyuejian.compare_bom_scope(input, changed).to_json()
    is { "right": { "source_sha256": String(changed_digest), .. }, .. } &&
    changed_digest != digest else {
    fail("Source hash failed to identify a byte change")
  }
}

///|
test "scope reports are deterministic and independent of view mutation" {
  let a = component("a", "1.0.0")
  let b = component("b", "1.0.0")
  let sorted = @mtyuejian.read_bom(bom(a + "," + b))
  let shuffled = @mtyuejian.read_bom(bom(b + "," + a))
  let result = @mtyuejian.compare_bom_scope(sorted, shuffled)
  assert_eq(result.exit_code(), 0)
  let original = result.to_json().stringify()
  guard result.to_json()
    is {
      "identities": Array(
        [
          {
            "left_ids": Array(a),
            "right_ids": Array(b),
            "repeated_identity": true,
            ..
          },
        ],
      ),
      ..
    } else {
    fail("Repeated exact identity not exposed")
  }
  assert_eq(a, b)
  a.clear()
  assert_eq(result.to_json().stringify(), original)
}
