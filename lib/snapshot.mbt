///|
/// A sorted, bounded collection of original documents. A snapshot is caller-
/// supplied evidence, not an authenticated or complete vulnerability database.
pub struct Snapshot {
  priv documents : Array[Advisory]
}

///|
/// Reject duplicate IDs, even for identical text. Conflicting revisions require
/// an explicit choice by the caller rather than a hidden last-writer policy.
pub fn Snapshot::new(
  documents : ArrayView[Advisory],
) -> Snapshot raise InputError {
  if documents.is_empty() || documents.length() > 64 {
    reject(
      "snapshot-limit", "/documents", "Expected 1 to 64 advisory documents",
    )
  }
  let sorted = documents.to_owned()
  sorted.sort_by((a, b) => text_order(a.id, b.id))
  let mut total = 0
  for i, document in sorted {
    total += document.raw.length() + document.origin.length()
    if total > 262144 {
      reject(
        "snapshot-size", "/documents", "Original documents and origin labels exceed 262144 UTF-16 code units in total",
      )
    }
    if i > 0 && sorted[i - 1].id == document.id {
      reject(
        "duplicate-advisory-id", "/documents", "Choose one revision for each advisory ID",
      )
    }
  }
  { documents: sorted, }
}

///|
/// Lossless snapshot-v1 envelope: original JSON is stored as text, so unknown
/// fields, numeric tokens, whitespace and source attribution survive round trips.
pub fn Snapshot::to_json(self : Snapshot) -> Json {
  {
    "schema_version": 1,
    "documents": Json(
      self.documents.map(d => { "origin": Json(d.origin), "text": Json(d.raw) }),
    ),
  }
}

///|
pub fn read_snapshot(input : String) -> Snapshot raise InputError {
  let fields = object(read_value(input, max_units=2097152), "")
  profile(fields, ["schema_version", "documents"])
  let docs = []
  for i, value in list(required(fields, "documents", ""), "/documents", 64) {
    let path = "/documents/" + i.to_string()
    let fields = object(value, path)
    known_fields(fields, ["origin", "text"], path)
    docs.push(
      read_advisory(
        text(required(fields, "text", path), pointer(path, "text")),
        origin=string_field(fields, "origin", path),
      ),
    )
  }
  Snapshot::new(docs)
}
