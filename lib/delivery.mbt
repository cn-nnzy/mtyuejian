///|
/// A self-contained, recomputed assessment and its exact evidence. The digest
/// detects changed content; it does not authenticate a publisher.
pub struct Delivery {
  priv assessment : Assessment
  priv inventory_text : String
  priv snapshot_text : String
  priv report_text : String
  priv digest : String
}

///|
fn delivery_digest(
  inventory : String,
  snapshot : String,
  report : String,
) -> String {
  // Domain-separated, UTF-8 byte-length framing prevents ambiguous concatenation.
  let framed = "yuejian-delivery-v1\n" +
    @utf8.encode(inventory).length().to_string() +
    ":" +
    inventory +
    @utf8.encode(snapshot).length().to_string() +
    ":" +
    snapshot +
    @utf8.encode(report).length().to_string() +
    ":" +
    report
  @hex.encode(Bytes::from_array(@crypto.sha256(@utf8.encode(framed))[:])[:])
}

///|
/// Capture all inputs and the resulting report. Caller ordering is normalized;
/// original advisory text and origin labels are retained inside the snapshot.
pub fn capture(
  snapshot : Snapshot,
  packages : ArrayView[Package],
) -> Delivery raise InputError {
  let inventory_text = inventory_json(packages).stringify()
  let packages = read_inventory(inventory_text)
  let assessment = assess(snapshot, packages)
  let snapshot_text = snapshot.to_json().stringify()
  let report_text = assessment.to_json().stringify()
  if inventory_text.length() + snapshot_text.length() + report_text.length() >
    1048576 {
    reject(
      "delivery-limit", "", "Combined delivery payload exceeds 1048576 UTF-16 code units",
    )
  }
  let digest = delivery_digest(inventory_text, snapshot_text, report_text)
  { assessment, inventory_text, snapshot_text, report_text, digest, }
}

///|
pub fn Delivery::assessment(self : Delivery) -> Assessment {
  self.assessment
}

///|
pub fn Delivery::digest(self : Delivery) -> String {
  self.digest
}

///|
/// Canonical delivery-v1 envelope. JSON strings preserve the exact framed inputs.
pub fn Delivery::to_json(self : Delivery) -> Json {
  {
    "schema_version": 1,
    "profile": Json("yuejian-delivery-v1"),
    "inventory": Json(self.inventory_text),
    "snapshot": Json(self.snapshot_text),
    "report": Json(self.report_text),
    "sha256": Json(self.digest),
  }
}

///|
/// Check framing, input validity, canonical encoding and the freshly recomputed
/// report. A digest-valid but invented report is rejected before it can be used.
pub fn verify_delivery(
  input : String,
  expected_sha256? : String,
) -> Delivery raise InputError {
  let fields = object(read_value(input, max_units=8388608), "")
  profile(fields, [
    "schema_version", "profile", "inventory", "snapshot", "report", "sha256",
  ])
  if text(required(fields, "profile", ""), "/profile") != "yuejian-delivery-v1" {
    reject("unsupported-delivery", "/profile", "Expected yuejian-delivery-v1")
  }
  let inventory = text(required(fields, "inventory", ""), "/inventory")
  let snapshot = text(required(fields, "snapshot", ""), "/snapshot")
  let report = text(required(fields, "report", ""), "/report")
  if inventory.length() + snapshot.length() + report.length() > 1048576 {
    reject(
      "delivery-limit", "", "Combined delivery payload exceeds 1048576 UTF-16 code units",
    )
  }
  let digest = text(required(fields, "sha256", ""), "/sha256")
  if digest.length() != 64 ||
    !digest.code_units().all(c => (c >= 48 && c <= 57) || (c >= 97 && c <= 102)) {
    reject(
      "invalid-digest", "/sha256", "Expected 64 lowercase hexadecimal SHA-256 digits",
    )
  }
  if digest != delivery_digest(inventory, snapshot, report) {
    reject(
      "digest-mismatch", "/sha256", "Delivery content does not match its digest",
    )
  }
  let rebuilt = capture(read_snapshot(snapshot), read_inventory(inventory))
  if rebuilt.inventory_text != inventory || rebuilt.snapshot_text != snapshot {
    reject(
      "noncanonical-delivery", "", "Delivery inputs must use canonical v1 serialization",
    )
  }
  if rebuilt.report_text != report {
    reject(
      "report-mismatch", "/report", "Saved report differs from the recomputed assessment",
    )
  }
  require_delivery_pin(rebuilt.digest, expected_sha256)
  rebuilt
}
