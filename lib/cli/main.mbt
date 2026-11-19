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
    if buffer.length() + chunk.length() > 4194304 {
      raise @audit.Invalid(
        code="file-limit",
        path~,
        message="Input exceeds 4 MiB",
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
    message="Use help for check, snapshot and replay syntax",
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
