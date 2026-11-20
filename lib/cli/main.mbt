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
    buffer.write_bytes(chunk)
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
    #|  changes BEFORE.delivery.json CURRENT.delivery.json
    #|  check-cdx BOM.json ADVISORY.json [ADVISORY.json ...]
    #|  sarif DELIVERY.json INVENTORY_URI
    #|  sarif-cdx BOM.json BOM_URI ADVISORY.json [ADVISORY.json ...]
    #|  help
    #|Reports and snapshots are JSON on stdout. Diagnostics are JSON on stderr.
    #|Exit: 0 not matched in supplied snapshot; 1 known version-range hit;
    #|      2 invalid input or usage; 3 incomplete assessment.
    #|This tool evaluates version evidence, not exploitability or software safety.
    #|
  help
}

///|
async fn snapshot_files(paths : ArrayView[String]) -> @audit.Snapshot {
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
  @audit.Snapshot::new(documents)
}

///|
async fn execute(args : Array[String]) -> Int32 {
  if args.length() == 1 && ["help", "--help", "-h"].contains(args[0]) {
    println(usage())
    return 0
  }
  if args.length() >= 2 && args[0] == "snapshot" {
    println(snapshot_files(args[1:]).to_json().stringify())
    return 0
  }
  if args.length() >= 3 && args[0] == "check" {
    let items = @audit.read_inventory(read_file(args[1]))
    let result = @audit.assess(snapshot_files(args[2:]), items)
    println(result.to_json().stringify())
    return result.exit_code()
  }
  if args.length() >= 3 && args[0] == "capture" {
    let items = @audit.read_inventory(read_file(args[1]))
    println(
      @audit.capture(snapshot_files(args[2:]), items).to_json().stringify(),
    )
    return 0
  }
  if args.length() == 2 && args[0] == "verify" {
    let result = @audit.verify_delivery(read_file(args[1])).assessment()
    println(result.to_json().stringify())
    return result.exit_code()
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
    let result = imported.assess(snapshot_files(args[2:]))
    println(result.to_json().stringify())
    return result.exit_code()
  }
  if args.length() == 3 && args[0] == "sarif" {
    let result = @audit.verify_delivery(read_file(args[1])).assessment()
    println(result.to_sarif(inventory_uri=args[2]).stringify())
    return result.exit_code()
  }
  if args.length() >= 4 && args[0] == "sarif-cdx" {
    let imported = @audit.read_cyclonedx(read_file(args[1]), origin=args[1])
    let result = imported.assess(snapshot_files(args[3:]))
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
