///|
/// A sorted, bounded collection of original documents. A snapshot is caller-
/// supplied evidence, not an authenticated or complete vulnerability database.
pub struct Snapshot {
  priv documents : Array[Advisory]
  priv crates_io : Bool
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
  { documents: sorted, crates_io: false, }
}

///|
/// Opt into the versioned crates.io ECOSYSTEM profile. Supported ranges are
/// validated once. The new schema-2 snapshot binds semantics into receipts;
/// schema-1 snapshots retain their original behavior and exact serialization.
pub fn Snapshot::with_crates_io(self : Snapshot) -> Snapshot raise InputError {
  if self.crates_io {
    return self
  }
  let documents = []
  for doc in self.documents {
    let affected = []
    for i, entry in doc.affected {
      let ranges = []
      for j, range in entry.ranges {
        let interpreted = if entry.ecosystem == Some("crates.io") &&
          range.kind == "ECOSYSTEM" {
          guard range.raw is Some(raw) else {
            reject(
              "missing-range-source", "", "Original ECOSYSTEM range is unavailable",
            )
            return self
          }
          read_range(
            raw,
            "/affected/" + i.to_string() + "/ranges/" + j.to_string(),
            crates_io=true,
          )
        } else {
          range
        }
        ranges.push(interpreted)
      }
      affected.push(Affected::{
        ecosystem: entry.ecosystem,
        name: entry.name,
        versions: entry.versions,
        ranges,
      })
    }
    documents.push(Advisory::{
      id: doc.id,
      modified: doc.modified,
      aliases: doc.aliases,
      withdrawn: doc.withdrawn,
      affected,
      origin: doc.origin,
      raw: doc.raw,
    })
  }
  { documents, crates_io: true, }
}

///|
fn Snapshot::evaluation_label(self : Snapshot) -> String {
  if self.crates_io {
    "crates-io-semver-v1"
  } else {
    "version-evidence-v1"
  }
}

///|
fn with_evaluation(view : Json, snapshot : Snapshot) -> Json {
  if snapshot.crates_io && view is Object(fields) {
    fields["evaluation_profile"] = Json(snapshot.evaluation_label())
  }
  view
}

///|
/// Lossless versioned snapshot: original text survives round trips. Legacy
/// snapshots use schema 1; explicit crates.io semantics use schema 2.
pub fn Snapshot::to_json(self : Snapshot) -> Json {
  let view : Json = {
    "schema_version": Json(if self.crates_io { 2 } else { 1 }),
    "documents": Json(
      self.documents.map(d => { "origin": Json(d.origin), "text": Json(d.raw) }),
    ),
  }
  with_evaluation(view, self)
}

///|
pub fn read_snapshot(input : String) -> Snapshot raise InputError {
  let fields = object(read_value(input, max_units=2097152), "")
  let crates_io = match required(fields, "schema_version", "") {
    Number("1") => {
      profile(fields, ["schema_version", "documents"])
      false
    }
    Number("2") => {
      known_fields(
        fields,
        ["schema_version", "evaluation_profile", "documents"],
        "",
      )
      if string_field(fields, "evaluation_profile", "") != "crates-io-semver-v1" {
        reject(
          "unsupported-evaluation-profile", "/evaluation_profile", "Expected crates-io-semver-v1",
        )
      }
      true
    }
    _ => {
      reject(
        "unsupported-profile", "/schema_version", "Expected snapshot schema 1 or 2",
      )
      false
    }
  }
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
  let snapshot = Snapshot::new(docs)
  if crates_io {
    snapshot.with_crates_io()
  } else {
    snapshot
  }
}
