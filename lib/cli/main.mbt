///|
async fn read_file(path : String) -> String {
  let file = @fs.open(path, mode=ReadOnly) catch {
    _ =>
      raise @audit.Invalid(
        code="cannot-open",
        path~,
        message="Cannot open input file",
      )
  }
  defer file.close()
  let buffer = @buffer.Buffer()
  while true {
    let chunk = file.read_some(max_len=65536) catch {
      _ =>
        raise @audit.Invalid(
          code="cannot-read",
          path~,
          message="Cannot read input file",
        )
    }
    guard chunk is Some(chunk) else { break }
    if buffer.length() + chunk.length() > 8388608 {
      raise @audit.Invalid(
        code="file-limit",
        path~,
        message="Input exceeds 8 MiB",
      )
    }
    buffer.write_bytesview(chunk)
  }
  @utf8.decode(buffer.to_bytes()) catch {
    _ =>
      raise @audit.Invalid(
        code="invalid-utf8",
        path~,
        message="Input must be strict UTF-8 without a BOM",
      )
  }
}

///|
fn usage() -> String {
  let help =
    #|月鉴 / Yuejian 0.1.0
    #|  check INVENTORY.json ADVISORY.json [ADVISORY.json ...]
    #|  snapshot ADVISORY.json [ADVISORY.json ...]
    #|  replay INVENTORY.json SNAPSHOT.json
    #|  capture INVENTORY.json ADVISORY.json [ADVISORY.json ...]
    #|  verify DELIVERY.json
    #|  coverage DELIVERY.json
    #|  coverage-bom BOM.delivery.json
    #|  coverage --expected-sha256 SHA256 DELIVERY.json
    #|  coverage-bom --expected-sha256 SHA256 BOM.delivery.json
    #|  aliases DELIVERY.json
    #|  aliases-bom BOM.delivery.json
    #|  review DELIVERY.json
    #|  review-bom BOM.delivery.json
    #|  review --expected-sha256 SHA256 DELIVERY.json
    #|  review-bom --expected-sha256 SHA256 BOM.delivery.json
    #|  verify --expected-sha256 SHA256 DELIVERY.json
    #|  verify-bom --expected-sha256 SHA256 BOM.delivery.json
    #|  changes --baseline-sha256 SHA256 BEFORE.delivery.json CURRENT.delivery.json
    #|  changes-bom --baseline-sha256 SHA256 BEFORE.bom.delivery.json CURRENT.bom.delivery.json
    #|  changes BEFORE.delivery.json CURRENT.delivery.json
    #|  check-cdx BOM.json ADVISORY.json [ADVISORY.json ...]
    #|  check-bom BOM.json ADVISORY.json [ADVISORY.json ...]
    #|  capture-bom BOM.json ADVISORY.json [ADVISORY.json ...]
    #|  verify-bom BOM.delivery.json
    #|  changes-bom BEFORE.bom.delivery.json CURRENT.bom.delivery.json
    #|  sarif-bom BOM.json BOM_URI ADVISORY.json [ADVISORY.json ...]
    #|  sarif-located DELIVERY.json INVENTORY.json INVENTORY_URI
    #|  sarif-bom-located BOM.json BOM_URI ADVISORY.json [ADVISORY.json ...]
    #|  sarif DELIVERY.json INVENTORY_URI
    #|  sarif-cdx BOM.json BOM_URI ADVISORY.json [ADVISORY.json ...]
    #|  help
    #|Add --crates-io immediately after check, capture, check-bom, capture-bom,
    #|check-cdx, snapshot or a BOM SARIF command to opt into crates.io ECOSYSTEM
    #|ordering. Saved snapshots/receipts retain the selected evaluation profile.
    #|Reports and snapshots are JSON on stdout. Diagnostics are JSON on stderr.
    #|Exit: 0 not matched in supplied snapshot; 1 known version-range hit;
    #|      2 invalid input or usage; 3 incomplete assessment.
    #|This tool evaluates version evidence, not exploitability or software safety.
    #|
  help
}

///|
async fn snapshot_files(
  paths : ArrayView[String],
  crates_io~ : Bool = false,
) -> @audit.Snapshot {
  if paths.is_empty() || paths.length() > 64 {
    raise @audit.Invalid(
      code="snapshot-limit",
      path="",
      message="Provide 1 to 64 advisory files",
    )
  }
  let documents = []
  for path in paths {
    documents.push(@audit.read_advisory(read_file(path), origin=path))
  }
  let snapshot = @audit.Snapshot::new(documents)
  if crates_io {
    snapshot.with_crates_io()
  } else {
    snapshot
  }
}

///|
async fn execute(input : Array[String]) -> Int32 {
  let crates_io = input.get(1) == Some("--crates-io")
  if crates_io &&
    (
      !input
      .get(0)
      .map(c => {
        [
          "check", "capture", "snapshot", "check-cdx", "check-bom", "capture-bom",
          "sarif-bom", "sarif-bom-located", "sarif-cdx",
        ].contains(c)
      })
      .unwrap_or(false) ||
      input.filter(a => a == "--crates-io").length() != 1
    ) {
    raise @audit.Invalid(
      code="usage",
      path="",
      message="--crates-io is accepted once, immediately after an assessment or snapshot command",
    )
  }
  let args = if crates_io { [input[0]] + input[2:].to_owned() } else { input }
  if (
      args.length() == 2 ||
      (args.length() == 4 && args[1] == "--expected-sha256")
    ) &&
    (args[0] == "coverage" || args[0] == "coverage-bom") {
    let path = args[args.length() - 1]
    let pin = if args.length() == 4 { Some(args[2]) } else { None }
    let view = if args[0] == "coverage" {
      let delivery = @audit.verify_delivery(
        read_file(path),
        expected_sha256?=pin,
      )
      delivery.assessment().coverage()
    } else {
      let delivery = @audit.verify_bom_delivery(
        read_file(path),
        expected_sha256?=pin,
      )
      delivery.assessment().coverage()
    }
    println(view.stringify())
    guard view is { "exit_code": Number(code, ..), .. } else {
      fail("Missing coverage gate")
    }
    return code.to_int()
  }
  if args.length() == 4 && args[1] == "--expected-sha256" {
    if args[0] == "review" {
      println(
        @audit.verify_delivery(read_file(args[3]), expected_sha256=args[2]).to_markdown(),
      )
      return 0
    }
    if args[0] == "review-bom" {
      println(
        @audit.verify_bom_delivery(read_file(args[3]), expected_sha256=args[2]).to_markdown(),
      )
      return 0
    }
    if args[0] == "verify" {
      let result = @audit.verify_delivery(
        read_file(args[3]),
        expected_sha256=args[2],
      ).assessment()
      println(result.to_json().stringify())
      return result.exit_code()
    }
    if args[0] == "verify-bom" {
      let result = @audit.verify_bom_delivery(
        read_file(args[3]),
        expected_sha256=args[2],
      ).assessment()
      println(result.to_json().stringify())
      return result.exit_code()
    }
  }
  if args.length() == 5 && args[1] == "--baseline-sha256" {
    if args[0] == "changes" {
      let before = @audit.verify_delivery(
        read_file(args[3]),
        expected_sha256=args[2],
      )
      let after = @audit.verify_delivery(read_file(args[4]))
      let result = @audit.compare_deliveries(before, after)
      println(result.to_json().stringify())
      return result.exit_code()
    }
    if args[0] == "changes-bom" {
      let before = @audit.verify_bom_delivery(
        read_file(args[3]),
        expected_sha256=args[2],
      )
      let after = @audit.verify_bom_delivery(read_file(args[4]))
      let result = @audit.compare_bom_deliveries(before, after)
      println(result.to_json().stringify())
      return result.exit_code()
    }
  }
  if args.length() == 1 && ["help", "--help", "-h"].contains(args[0]) {
    println(usage())
    return 0
  }
  if args.length() >= 2 && args[0] == "snapshot" {
    println(snapshot_files(args[1:], crates_io~).to_json().stringify())
    return 0
  }
  if args.length() >= 3 && args[0] == "check" {
    let items = @audit.read_inventory(read_file(args[1]))
    let result = @audit.assess(snapshot_files(args[2:], crates_io~), items)
    println(result.to_json().stringify())
    return result.exit_code()
  }
  if args.length() >= 3 && args[0] == "capture" {
    let items = @audit.read_inventory(read_file(args[1]))
    println(
      @audit.capture(snapshot_files(args[2:], crates_io~), items)
      .to_json()
      .stringify(),
    )
    return 0
  }
  if args.length() == 2 && args[0] == "verify" {
    let result = @audit.verify_delivery(read_file(args[1])).assessment()
    println(result.to_json().stringify())
    return result.exit_code()
  }
  if args.length() == 2 && args[0] == "aliases" {
    let delivery = @audit.verify_delivery(read_file(args[1]))
    println(delivery.alias_review().stringify())
    return delivery.assessment().exit_code()
  }
  if args.length() == 2 && args[0] == "review" {
    println(@audit.verify_delivery(read_file(args[1])).to_markdown())
    return 0
  }
  if args.length() == 2 && args[0] == "review-bom" {
    println(@audit.verify_bom_delivery(read_file(args[1])).to_markdown())
    return 0
  }
  if args.length() == 2 && args[0] == "aliases-bom" {
    let delivery = @audit.verify_bom_delivery(read_file(args[1]))
    println(delivery.alias_review().stringify())
    return delivery.assessment().exit_code()
  }
  if args.length() == 3 && args[0] == "changes" {
    let before = @audit.verify_delivery(read_file(args[1]))
    let current = @audit.verify_delivery(read_file(args[2]))
    let changes = @audit.compare_deliveries(before, current)
    println(changes.to_json().stringify())
    return changes.exit_code()
  }
  if args.length() >= 3 && args[0] == "check-cdx" {
    let imported = @audit.read_cyclonedx(read_file(args[1]), origin=args[1])
    let result = imported.assess(snapshot_files(args[2:], crates_io~))
    println(result.to_json().stringify())
    return result.exit_code()
  }
  if args.length() >= 3 && args[0] == "check-bom" {
    let imported = @audit.read_bom(read_file(args[1]), origin=args[1])
    let result = imported.assess(snapshot_files(args[2:], crates_io~))
    println(result.to_json().stringify())
    return result.exit_code()
  }
  if args.length() >= 3 && args[0] == "capture-bom" {
    let imported = @audit.read_bom(read_file(args[1]), origin=args[1])
    println(
      @audit.capture_bom(snapshot_files(args[2:], crates_io~), imported)
      .to_json()
      .stringify(),
    )
    return 0
  }
  if args.length() == 2 && args[0] == "verify-bom" {
    let result = @audit.verify_bom_delivery(read_file(args[1])).assessment()
    println(result.to_json().stringify())
    return result.exit_code()
  }
  if args.length() == 3 && args[0] == "changes-bom" {
    let before = @audit.verify_bom_delivery(read_file(args[1]))
    let current = @audit.verify_bom_delivery(read_file(args[2]))
    let result = @audit.compare_bom_deliveries(before, current)
    println(result.to_json().stringify())
    return result.exit_code()
  }
  if args.length() >= 4 && args[0] == "sarif-bom" {
    let imported = @audit.read_bom(read_file(args[1]), origin=args[1])
    let result = imported.assess(snapshot_files(args[3:], crates_io~))
    println(result.to_sarif(bom_uri=args[2]).stringify())
    return result.exit_code()
  }
  if args.length() == 3 && args[0] == "sarif" {
    let result = @audit.verify_delivery(read_file(args[1])).assessment()
    println(result.to_sarif(inventory_uri=args[2]).stringify())
    return result.exit_code()
  }
  if args.length() == 4 && args[0] == "sarif-located" {
    let result = @audit.verify_delivery(read_file(args[1])).assessment()
    println(
      result
      .to_sarif(inventory_uri=args[3], inventory_source=read_file(args[2]))
      .stringify(),
    )
    return result.exit_code()
  }
  if args.length() >= 4 && args[0] == "sarif-bom-located" {
    let imported = @audit.read_bom(read_file(args[1]), origin=args[1])
    let result = imported.assess(snapshot_files(args[3:], crates_io~))
    println(result.to_sarif(bom_uri=args[2], locate=true).stringify())
    return result.exit_code()
  }
  if args.length() >= 4 && args[0] == "sarif-cdx" {
    let imported = @audit.read_cyclonedx(read_file(args[1]), origin=args[1])
    let result = imported.assess(snapshot_files(args[3:], crates_io~))
    println(result.to_sarif(bom_uri=args[2]).stringify())
    return result.exit_code()
  }
  if args.length() == 3 && args[0] == "replay" {
    let items = @audit.read_inventory(read_file(args[1]))
    let snapshot = @audit.read_snapshot(read_file(args[2]))
    let result = @audit.assess(snapshot, items)
    println(result.to_json().stringify())
    return result.exit_code()
  }
  raise @audit.Invalid(
    code="usage",
    path="",
    message="Use help for available commands and syntax",
  )
}

///|
async fn main {
  let args = @env.args()[1:].to_owned()
  let code = execute(args) catch {
    @audit.Invalid(..) as error => {
      @stdio.stderr.write(@utf8.encode(error.to_json().stringify() + "\n"))
      2
    }
    _ => {
      @stdio.stderr.write(
        b"{\"code\":\"host-error\",\"path\":\"\",\"message\":\"Host operation failed\"}\n",
      )
      2
    }
  }
  @env.exit(code)
}
