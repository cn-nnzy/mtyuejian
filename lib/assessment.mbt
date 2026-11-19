///|
/// NotMatched is scoped to supplied records, never a statement of software safety.
#derive(Eq, Debug)
pub(all) enum Outcome {
  Affected
  NotMatched
  Undetermined
  Withdrawn
  NoAdvisory
}

///|
pub extend Outcome with Eq::{equal, not_equal}

///|
pub extend Outcome with @debug.Debug::{to_repr}

///|
fn Outcome::label(self : Outcome) -> String {
  match self {
    Affected => "affected"
    NotMatched => "not_matched"
    Undetermined => "undetermined"
    Withdrawn => "withdrawn"
    NoAdvisory => "no_advisory"
  }
}

///|
priv struct Evidence {
  path : String
  code : String
  indices : Array[Int32]
}

///|
priv struct Decision {
  item : Package
  advisory : String?
  outcome : Outcome
  evidence : Array[Evidence]
  incomplete : Bool
}

///|
/// Immutable assessment state. Each to_json call constructs an independent view.
pub struct Assessment {
  priv decisions : Array[Decision]
  priv unscoped : Array[(String, String)]
  priv snapshot : Snapshot
}

///|
fn range_evidence(
  range : Range,
  query : Version?,
  path : String,
) -> (Bool, Bool, Array[Evidence]) {
  if range.kind != "SEMVER" {
    return (false, true, [{ path, code: "unsupported-range", indices: [], }])
  }
  guard query is Some(query) else {
    return (false, true, [{ path, code: "query-is-not-semver", indices: [], }])
  }
  if !range.limits.is_empty() {
    let before_limit = range.limits.any(limit => {
      match limit.version {
        None => true
        Some(boundary) => query.compare(boundary) < 0
      }
    })
    if !before_limit {
      return (
        false,
        false,
        [
          {
            path,
            code: "outside-limits",
            indices: range.limits.map(e => e.index),
          },
        ],
      )
    }
  }
  for interval in range.intervals {
    let above = match interval.lower {
      None => true
      Some(lower) => query.compare(lower) >= 0
    }
    let below = match interval.upper {
      None => true
      Some(upper) =>
        if interval.inclusive {
          query.compare(upper) <= 0
        } else {
          query.compare(upper) < 0
        }
    }
    if above && below {
      let indices = [interval.first]
      if interval.last is Some(last) {
        indices.push(last)
      }
      for limit in range.limits {
        indices.push(limit.index)
      }
      return (true, false, [{ path, code: "semver-interval", indices, }])
    }
  }
  (false, false, [{ path, code: "outside-semver-intervals", indices: [], }])
}

///|
fn decide(item : Package, advisory : Advisory) -> Decision? {
  let relevant = advisory.affected.any(a => {
    a.ecosystem == Some(item.ecosystem) && a.name == Some(item.name)
  })
  if !relevant {
    return None
  }
  if advisory.withdrawn {
    return Some({
      item,
      advisory: Some(advisory.id),
      outcome: Withdrawn,
      evidence: [{ path: "/withdrawn", code: "withdrawn-record", indices: [], }],
      incomplete: true,
    })
  }
  let query = parse_version(item.version)
  let evidence = []
  let mut hit = false
  let mut incomplete = false
  for i, entry in advisory.affected {
    if entry.ecosystem != Some(item.ecosystem) || entry.name != Some(item.name) {
      continue
    }
    let path = "/affected/" + i.to_string()
    let mixed_git = entry.ranges.any(r => r.kind == "GIT")
    if mixed_git && !entry.versions.is_empty() {
      incomplete = true
      evidence.push({
        path: pointer(path, "versions"),
        code: "git-tags-not-package-versions",
        indices: [],
      })
    } else {
      for j, version in entry.versions {
        if item.version == version {
          hit = true
          evidence.push({
            path: pointer(pointer(path, "versions"), j.to_string()),
            code: "enumerated-version",
            indices: [],
          })
        }
      }
    }
    if entry.versions.is_empty() && entry.ranges.is_empty() {
      incomplete = true
      evidence.push({ path, code: "missing-version-evidence", indices: [], })
    }
    for j, range in entry.ranges {
      let (matched, unknown, details) = range_evidence(
        range,
        query,
        pointer(pointer(path, "ranges"), j.to_string()),
      )
      hit = hit || matched
      incomplete = incomplete || unknown
      evidence.append(details)
    }
  }
  Some({
    item,
    advisory: Some(advisory.id),
    outcome: if hit {
      Affected
    } else if incomplete {
      Undetermined
    } else {
      NotMatched
    },
    evidence,
    incomplete,
  })
}

///|
/// Assess exact (ecosystem, name) identities. Evidence arrays retain original OSV
/// indices even when events were sorted for evaluation. No I/O or clock is used.
pub fn assess(
  snapshot : Snapshot,
  packages : ArrayView[Package],
) -> Assessment raise InputError {
  inventory_json(packages) |> ignore
  if packages.length() * snapshot.documents.length() > 16384 {
    reject(
      "assessment-limit", "/packages", "At most 16384 package/document pairs are supported",
    )
  }
  let sorted = packages.to_owned()
  sorted.sort_by((a, b) => text_order(a.id, b.id))
  let decisions = []
  let unscoped = []
  for document in snapshot.documents {
    if !document.withdrawn {
      for i, entry in document.affected {
        if entry.ecosystem is None || entry.name is None {
          unscoped.push((document.id, "/affected/" + i.to_string()))
        }
      }
    }
  }
  for item in sorted {
    let mut found = false
    for document in snapshot.documents {
      if decide(item, document) is Some(decision) {
        decisions.push(decision)
        found = true
      }
    }
    if !found {
      decisions.push({
        item,
        advisory: None,
        outcome: NoAdvisory,
        evidence: [{ path: "", code: "no-matching-advisory", indices: [], }],
        incomplete: true,
      })
    }
  }
  { decisions, unscoped, snapshot, }
}

///|
/// 0: all scoped decisions NotMatched; 1: at least one known hit; 3: incomplete.
/// Input errors are raised before an assessment exists (CLI exit 2).
pub fn Assessment::exit_code(self : Assessment) -> Int32 {
  if self.decisions.any(d => d.outcome == Affected) {
    return 1
  }
  if !self.unscoped.is_empty() || self.decisions.any(d => d.incomplete) {
    return 3
  }
  0
}

///|
/// Results ordered by caller package ID, then advisory ID.
pub fn Assessment::outcomes(self : Assessment) -> Array[Outcome] {
  self.decisions.map(d => d.outcome)
}

///|
pub fn Assessment::to_json(self : Assessment) -> Json {
  let counts : Map[String, Int32] = Map([])
  for outcome in [Affected, NotMatched, Undetermined, Withdrawn, NoAdvisory] {
    counts[outcome.label()] = self.decisions
      .filter(d => d.outcome == outcome)
      .length()
  }
  {
    "schema_version": 1,
    "scope": "version-range-only; supplied snapshot; no exploitability claim",
    "exit_code": Json(self.exit_code()),
    "counts": Json(counts),
    "advisories": Json(
      self.snapshot.documents.map(d => {
        "id": Json(d.id),
        "modified": Json(d.modified),
        "origin": Json(d.origin),
        "aliases": Json(d.aliases),
        "withdrawn": Json(d.withdrawn),
      }),
    ),
    "unscoped_entries": Json(
      self.unscoped.map(pair => {
        "advisory": Json(pair.0),
        "path": Json(pair.1),
        "code": Json("package-identity-missing"),
      }),
    ),
    "decisions": Json(
      self.decisions.map(d => {
        "package": d.item.to_json(),
        "advisory": match d.advisory {
          None => Json::null()
          Some(id) => Json(id)
        },
        "outcome": Json(d.outcome.label()),
        "incomplete": Json(d.incomplete),
        "evidence": Json(
          d.evidence.map(e => {
            "path": Json(e.path),
            "code": Json(e.code),
            "event_indices": Json(e.indices),
          }),
        ),
      }),
    ),
  }
}
