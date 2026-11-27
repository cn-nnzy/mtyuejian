///|
priv struct Event {
  kind : String
  version : Version?
  index : Int32
}

///|
priv struct Interval {
  lower : Version?
  upper : Version?
  inclusive : Bool
  first : Int32
  last : Int32?
}

///|
priv struct Range {
  kind : String
  intervals : Array[Interval]
  limits : Array[Event]
  crates_io : Bool
  raw : Value?
}

///|
priv struct Affected {
  ecosystem : String?
  name : String?
  versions : Array[String]
  ranges : Array[Range]
}

///|
/// Validated version-assessment profile plus the exact, unmodified OSV source.
pub struct Advisory {
  priv id : String
  priv modified : String
  priv aliases : Array[String]
  priv withdrawn : Bool
  priv affected : Array[Affected]
  priv origin : String
  priv raw : String
}

///|
pub fn Advisory::id(self : Advisory) -> String {
  self.id
}

///|
/// Return the exact original document, including fields outside the assessment profile.
pub fn Advisory::source(self : Advisory) -> String {
  self.raw
}

///|
fn read_strings(
  values : Array[Value],
  path : String,
) -> Array[String] raise InputError {
  let strings = []
  for i, value in values {
    strings.push(
      nonempty(
        text(value, pointer(path, i.to_string())),
        pointer(path, i.to_string()),
      ),
    )
  }
  strings
}

///|
fn event_compare(a : Event, b : Event) -> Int32 {
  match (a.version, b.version) {
    (None, None) => a.index.compare(b.index)
    (None, Some(_)) => -1
    (Some(_), None) => 1
    (Some(av), Some(bv)) => {
      let order = av.compare(bv)
      if order != 0 {
        return order
      }
      // A singleton [v,v] is legitimate when closed by last_affected.
      if a.kind == "introduced" && b.kind == "last_affected" {
        return -1
      }
      if b.kind == "introduced" && a.kind == "last_affected" {
        return 1
      }
      a.index.compare(b.index)
    }
  }
}

///|
fn read_range(
  value : Value,
  path : String,
  crates_io~ : Bool = false,
) -> Range raise InputError {
  let fields = object(value, path)
  known_fields(fields, ["type", "events", "repo", "database_specific"], path)
  let kind = string_field(fields, "type", path)
  let events = list(
    required(fields, "events", path),
    pointer(path, "events"),
    4096,
  )
  if events.is_empty() {
    reject(
      "empty-events",
      pointer(path, "events"),
      "A range needs at least one event",
    )
  }
  let crates_io = crates_io && kind == "ECOSYSTEM"
  let transition_label = if crates_io {
    "crates.io ECOSYSTEM"
  } else {
    "SEMVER"
  }
  if kind != "SEMVER" && !crates_io {
    // Preserve unsupported event syntax in raw source; never pretend to evaluate it.
    if kind == "GIT" {
      string_field(fields, "repo", path) |> ignore
    }
    return {
      kind,
      intervals: [],
      limits: [],
      crates_io: false,
      raw: if kind == "ECOSYSTEM" {
        Some(value)
      } else {
        None
      },
    }
  }
  let controls : Array[Event] = []
  let limits = []
  for i, value in events {
    let ep = pointer(pointer(path, "events"), i.to_string())
    let event = object(value, ep)
    if event.length() != 1 {
      reject(
        "invalid-event",
        ep,
        "Each " +
        transition_label +
        " event must contain exactly one transition",
      )
    }
    for key, value in event {
      if !["introduced", "fixed", "last_affected", "limit"].contains(key) {
        reject(
          "unsupported-event",
          pointer(ep, key),
          "Unknown " + transition_label + " transition",
        )
      }
      let value = text(value, pointer(ep, key))
      let version = if (key == "introduced" && value == "0") ||
        (key == "limit" && value == "*") {
        None
      } else {
        Some(
          if crates_io {
            crate_version_at(value, pointer(ep, key))
          } else {
            version_at(value, pointer(ep, key))
          },
        )
      }
      let event = Event::{ kind: key, version, index: i, }
      if key == "limit" {
        limits.push(event)
      } else {
        controls.push(event)
      }
    }
  }
  controls.sort_by(event_compare)
  let intervals = []
  let mut opened : Event? = None
  let mut previous : Event? = None
  for event in controls {
    if previous is Some(prev) &&
      prev.version is Some(a) &&
      event.version is Some(b) &&
      a.compare(b) == 0 {
      if !(prev.kind == "introduced" && event.kind == "last_affected") {
        reject(
          "ambiguous-events",
          pointer(path, "events"),
          "Transitions with equal SemVer precedence are ambiguous",
        )
      }
    }
    if event.kind == "introduced" {
      if opened is Some(_) {
        reject(
          "contradictory-events",
          pointer(path, "events"),
          "An introduced event precedes closure of the previous interval",
        )
      }
      opened = Some(event)
    } else {
      guard opened is Some(start) else {
        reject(
          "contradictory-events",
          pointer(path, "events"),
          "A closing event has no preceding introduction",
        )
        return { kind, intervals: [], limits, crates_io, raw: None, }
      }
      intervals.push({
        lower: start.version,
        upper: event.version,
        inclusive: event.kind == "last_affected",
        first: start.index,
        last: Some(event.index),
      })
      opened = None
    }
    previous = Some(event)
  }
  if opened is Some(start) {
    intervals.push({
      lower: start.version,
      upper: None,
      inclusive: false,
      first: start.index,
      last: None,
    })
  }
  if intervals.is_empty() {
    reject(
      "missing-introduction",
      pointer(path, "events"),
      "A " + transition_label + " range needs an introduced event",
    )
  }
  { kind, intervals, limits, crates_io, raw: None, }
}

///|
/// Read an OSV 1.0.0–1.9.2 version-assessment profile. This is not a full schema
/// validator. Unsupported range types remain present for Undetermined results.
pub fn read_advisory(
  input : String,
  origin~ : String = "memory",
) -> Advisory raise InputError {
  let fields = object(read_value(input), "")
  let origin = nonempty(origin, "/origin")
  let id = string_field(fields, "id", "")
  if !id
    .code_units()
    .all(c => {
      (c >= 48 && c <= 57) ||
      (c >= 65 && c <= 90) ||
      (c >= 97 && c <= 122) ||
      [58, 95, 46, 45].contains(c.to_int())
    }) {
    reject(
      "invalid-advisory-id", "/id", "OSV IDs must use ASCII letters, digits, colon, underscore, dot or hyphen",
    )
  }
  let schema = match fields.get("schema_version") {
    None => "1.0.0"
    Some(value) => text(value, "/schema_version")
  }
  let sv = version_at(schema, "/schema_version")
  let low = version_at("1.0.0", "")
  let high = version_at("1.9.2", "")
  if !sv.pre.is_empty() ||
    schema.contains("+") ||
    sv.compare(low) < 0 ||
    sv.compare(high) > 0 {
    reject(
      "unsupported-osv-version", "/schema_version", "Supported schema versions are 1.0.0 through 1.9.2",
    )
  }
  let modified = timestamp_field(fields, "modified", "")
  if fields.contains("published") {
    timestamp_field(fields, "published", "") |> ignore
  }
  let withdrawn = fields.contains("withdrawn")
  if withdrawn {
    timestamp_field(fields, "withdrawn", "") |> ignore
  }
  let aliases = read_strings(
    optional_list(fields, "aliases", "", 128),
    "/aliases",
  )
  let affected = []
  for i, value in optional_list(fields, "affected", "", 256) {
    let path = "/affected/" + i.to_string()
    let entry = object(value, path)
    let (ecosystem, name) = match entry.get("package") {
      None => (None, None)
      Some(value) => {
        let p = object(value, pointer(path, "package"))
        (
          Some(string_field(p, "ecosystem", pointer(path, "package"))),
          Some(string_field(p, "name", pointer(path, "package"))),
        )
      }
    }
    let versions = read_strings(
      optional_list(entry, "versions", path, 8192),
      pointer(path, "versions"),
    )
    let ranges = []
    for j, range in optional_list(entry, "ranges", path, 128) {
      ranges.push(
        read_range(range, pointer(pointer(path, "ranges"), j.to_string())),
      )
    }
    affected.push(Affected::{ ecosystem, name, versions, ranges, })
  }
  { id, modified, aliases, withdrawn, affected, origin, raw: input, }
}
