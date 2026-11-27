///|
fn generated_bom(padding : Int32) -> String {
  let rows = Array::makei(1024, i => {
    let version = if i % 2 == 0 { "0.2.22" } else { "0.2.23" }
    "{\"type\":\"library\",\"bom-ref\":\"instance-\{i}\",\"name\":\"time\",\"version\":\"\{version}\",\"purl\":\"pkg:cargo/time@\{version}\"}"
  })
  "{\"bomFormat\":\"CycloneDX\",\"specVersion\":\"1.6\",\"components\":[" +
  rows.join(",") +
  "],\"properties\":[{\"name\":\"benchmark:padding\",\"value\":\"" +
  "x".repeat(padding) +
  "\"}]}"
}

///|
fn run_phase(
  phase : String,
  raw : String,
  snapshot : @audit.Snapshot,
  imported : @audit.BomImport,
  receipt : String,
  pin : String,
  expected_gate : Int32,
) -> Int32 raise {
  match phase {
    "parse" => {
      let parsed = @audit.read_bom(raw)
      assert_eq(parsed.source(), raw)
      // Keep parse results observable without allocating a report.
      parsed.source().length()
    }
    "assess" => {
      let result = imported.assess(snapshot)
      assert_eq(result.exit_code(), expected_gate)
      result.exit_code()
    }
    "capture" => {
      let encoded = @audit.capture_bom(snapshot, imported).to_json().stringify()
      assert_true(!encoded.is_empty())
      encoded.length()
    }
    "replay" => {
      let restored = @audit.verify_bom_delivery(receipt, expected_sha256=pin)
      assert_eq(restored.assessment().exit_code(), expected_gate)
      restored.digest().length()
    }
    _ => fail("Unknown benchmark phase")
  }
}

///|
async fn main {
  let args = @env.args()
  guard args is [_, workload, phase, bom_path, ..] &&
    ["real", "max-components", "max-json"].contains(workload) &&
    ["parse", "assess", "capture", "replay"].contains(phase) &&
    (workload != "max-json" || phase == "parse") else {
    fail("Expected WORKLOAD PHASE REAL_BOM")
  }
  let advice = if workload == "real" {
    "samples/RUSTSEC-2021-0145.json"
  } else {
    "samples/RUSTSEC-2020-0071.json"
  }
  let snapshot = @audit.Snapshot::new([
    @audit.read_advisory(@fs.read_file(advice).text(), origin=advice),
  ])
  let raw = match workload {
    "real" => @fs.read_file(bom_path).text()
    "max-json" => generated_bom(1048576 - generated_bom(0).length())
    _ => generated_bom(120000)
  }
  let imported = @audit.read_bom(raw)
  let expected_gate = 1
  let (receipt, pin) = if phase == "replay" {
    let saved = @audit.capture_bom(snapshot, imported)
    assert_eq(saved.assessment().exit_code(), expected_gate)
    (saved.to_json().stringify(), saved.digest())
  } else {
    ("", "")
  }
  let repeats = if workload == "real" { 40 } else { 6 }
  let expected = run_phase(
    phase, raw, snapshot, imported, receipt, pin, expected_gate,
  )
  let start = @env.now()
  for _ in 0..<repeats {
    assert_eq(
      run_phase(phase, raw, snapshot, imported, receipt, pin, expected_gate),
      expected,
    )
  }
  let end = @env.now()
  assert_true(end >= start)
  let report : Json = {
    "workload": Json(workload),
    "phase": Json(phase),
    "input_utf16": Json(raw.length()),
    "iterations": Json(repeats),
    "batch_ms": Json((end - start).to_double()),
    "result": Json(expected),
  }
  println(report.stringify())
}
