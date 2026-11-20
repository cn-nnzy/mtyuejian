///|
/// A full BOM assessment receipt, including unresolved identities and raw source.
/// Integrity verification recomputes the outer gate; it does not authenticate data.
pub struct BomDelivery {
  priv result : BomAssessment
  priv snapshot_text : String
  priv report_text : String
  priv digest : String
}

///|
fn bom_delivery_digest(
  profile : String,
  source : String,
  origin : String,
  snapshot : String,
  report : String,
) -> String {
  let framed = StringBuilder()
  framed.write_string("yuejian-bom-delivery-v1\n")
  for part in [profile, source, origin, snapshot, report] {
    framed.write_string(@utf8.encode(part).length().to_string())
    framed.write_string(":")
    framed.write_string(part)
  }
  @hex.encode(
    Bytes::from_array(@crypto.sha256(@utf8.encode(framed.to_string()))[:])[:],
  )
}

///|
fn bom_delivery_budget(
  profile : String,
  source : String,
  origin : String,
  snapshot : String,
  report : String,
) -> Unit raise InputError {
  if profile.length() +
    source.length() +
    origin.length() +
    snapshot.length() +
    report.length() >
    1048576 {
    reject(
      "bom-delivery-limit", "", "Combined BOM delivery payload exceeds 1048576 UTF-16 code units",
    )
  }
}

///|
pub fn capture_bom(
  snapshot : Snapshot,
  imported : BomImport,
) -> BomDelivery raise InputError {
  let result = imported.assess(snapshot)
  let snapshot_text = snapshot.to_json().stringify()
  let report_text = result.to_json().stringify()
  bom_delivery_budget(
    imported.profile,
    imported.raw,
    imported.origin,
    snapshot_text,
    report_text,
  )
  let digest = bom_delivery_digest(
    imported.profile,
    imported.raw,
    imported.origin,
    snapshot_text,
    report_text,
  )
  { result, snapshot_text, report_text, digest, }
}

///|
pub fn BomDelivery::assessment(self : BomDelivery) -> BomAssessment {
  self.result
}

///|
pub fn BomDelivery::digest(self : BomDelivery) -> String {
  self.digest
}

///|
pub fn BomDelivery::to_json(self : BomDelivery) -> Json {
  {
    "schema_version": 1,
    "profile": Json("yuejian-bom-delivery-v1"),
    "input_profile": Json(self.result.imported.profile),
    "bom": Json(self.result.imported.raw),
    "origin": Json(self.result.imported.origin),
    "snapshot": Json(self.snapshot_text),
    "report": Json(self.report_text),
    "sha256": Json(self.digest),
  }
}

///|
/// Rebuild both the resolved assessment and unresolved rows. Digest-valid invented
/// reports are rejected; source text is retained rather than normalized.
pub fn verify_bom_delivery(
  input : String,
  expected_sha256? : String,
) -> BomDelivery raise InputError {
  let fields = object(read_value(input, max_units=8388608), "")
  profile(fields, [
    "schema_version", "profile", "input_profile", "bom", "origin", "snapshot", "report",
    "sha256",
  ])
  if string_field(fields, "profile", "") != "yuejian-bom-delivery-v1" {
    reject(
      "unsupported-bom-delivery", "/profile", "Expected yuejian-bom-delivery-v1",
    )
  }
  let format = string_field(fields, "input_profile", "")
  let source = text(required(fields, "bom", ""), "/bom")
  let origin = string_field(fields, "origin", "")
  let snapshot = text(required(fields, "snapshot", ""), "/snapshot")
  let report = text(required(fields, "report", ""), "/report")
  bom_delivery_budget(format, source, origin, snapshot, report)
  let digest = string_field(fields, "sha256", "")
  if digest.length() != 64 ||
    !digest.code_units().all(c => (c >= 48 && c <= 57) || (c >= 97 && c <= 102)) {
    reject(
      "invalid-digest", "/sha256", "Expected 64 lowercase hexadecimal SHA-256 digits",
    )
  }
  if digest != bom_delivery_digest(format, source, origin, snapshot, report) {
    reject(
      "digest-mismatch", "/sha256", "BOM delivery content does not match its digest",
    )
  }
  let imported = match format {
    "cyclonedx-cargo-v1" => read_cyclonedx(source, origin~)
    "spdx-cargo-v1" => read_spdx(source, origin~)
    _ => {
      reject(
        "unsupported-bom-profile", "/input_profile", "Expected cyclonedx-cargo-v1 or spdx-cargo-v1",
      )
      read_bom(source, origin~)
    }
  }
  let rebuilt = capture_bom(read_snapshot(snapshot), imported)
  if rebuilt.snapshot_text != snapshot {
    reject(
      "noncanonical-delivery", "/snapshot", "Snapshot must use canonical v1 serialization",
    )
  }
  if rebuilt.report_text != report {
    reject(
      "report-mismatch", "/report", "Saved BOM report differs from the recomputed outer assessment",
    )
  }
  require_delivery_pin(rebuilt.digest, expected_sha256)
  rebuilt
}
