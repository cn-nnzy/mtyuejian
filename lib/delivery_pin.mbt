///|
fn require_delivery_pin(
  actual : String,
  expected : String?,
) -> Unit raise InputError {
  if expected is Some(expected) {
    if expected.length() != 64 ||
      !expected
      .code_units()
      .all(c => (c >= 48 && c <= 57) || (c >= 97 && c <= 102)) {
      reject(
        "invalid-expected-digest", "/expected_sha256", "Expected a separately supplied 64-character lowercase hexadecimal SHA-256",
      )
    }
    if actual != expected {
      reject(
        "delivery-pin-mismatch", "/sha256", "Verified receipt does not match the independently pinned SHA-256",
      )
    }
  }
}
