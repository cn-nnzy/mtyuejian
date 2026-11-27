///|
priv struct ChangeEntry {
  category : String
  before : Decision?
  after : Decision?
  causes : Array[String]
  new_hit : Bool
  missing : Bool
}

///|
/// Changes between two captured or verified deliveries. The delta gate never
/// replaces the current delivery's absolute assessment gate.
pub struct Changes {
  priv before : Delivery
  priv after : Delivery
  priv entries : Array[ChangeEntry]
  priv identities : Array[(Package, Package)]
}

///|
fn package_key(item : Package) -> String {
  Json([Json(item.id), Json(item.ecosystem), Json(item.name)]).stringify()
}

///|
fn decision_key(row : Decision) -> String {
  Json([
    Json(package_key(row.item)),
    match row.advisory {
      None => Json::null()
      Some(id) => Json(id)
    },
  ]).stringify()
}

///|
fn advisory_sources(snapshot : Snapshot) -> Map[String, String] {
  let result = Map([])
  for doc in snapshot.documents {
    result[doc.id] = Json([Json(doc.raw), Json(doc.origin)]).stringify()
  }
  result
}

///|
/// Match exact installation ID, ecosystem, package name and primary advisory ID.
/// Versions may change; aliases never merge rows. Removed evidence requires review.
pub fn compare_deliveries(before : Delivery, after : Delivery) -> Changes {
  let (entries, identities) = decision_changes(
    before.assessment,
    after.assessment,
  )
  { before, after, entries, identities, }
}

///|
fn decision_changes(
  before : Assessment,
  after : Assessment,
) -> (Array[ChangeEntry], Array[(Package, Package)]) {
  let old : Map[String, Decision] = Map([])
  let current : Map[String, Decision] = Map([])
  let keys = []
  let old_items : Map[String, Package] = Map([])
  let new_items : Map[String, Package] = Map([])
  let current_identities : Map[String, Unit] = Map([])
  for row in before.decisions {
    let key = decision_key(row)
    old[key] = row
    keys.push(key)
    old_items[row.item.id] = row.item
  }
  for row in after.decisions {
    let key = decision_key(row)
    current[key] = row
    if !old.contains(key) {
      keys.push(key)
    }
    new_items[row.item.id] = row.item
    current_identities[package_key(row.item)] = ()
  }
  keys.sort_by(text_order)
  let ids = old_items.keys().collect()
  ids.sort_by(text_order)
  let identities = []
  for id in ids {
    if new_items.get(id) is Some(now) {
      let prior = old_items[id]
      if prior.ecosystem != now.ecosystem || prior.name != now.name {
        identities.push((prior, now))
      }
    }
  }
  let old_sources = advisory_sources(before.snapshot)
  let new_sources = advisory_sources(after.snapshot)
  let entries = []
  for key in keys {
    let prior = old.get(key)
    let now = current.get(key)
    let causes = []
    let category = match (prior, now) {
      (None, Some(_)) => "added"
      (Some(_), None) => "removed"
      (Some(a), Some(b)) => {
        if a.item.version != b.item.version {
          causes.push("package-version")
        }
        if a.advisory is Some(id) && old_sources.get(id) != new_sources.get(id) {
          causes.push("advisory-source")
        }
        let different = a.to_json().stringify() != b.to_json().stringify()
        if b.outcome == Affected && a.outcome != Affected {
          "newly-affected"
        } else if a.outcome == Affected && b.outcome == NotMatched {
          "no-longer-matched"
        } else if b.incomplete && !a.incomplete {
          "became-incomplete"
        } else if different || !causes.is_empty() {
          "changed"
        } else {
          "unchanged"
        }
      }
      (None, None) => "unchanged"
    }
    let new_hit = match now {
      Some(row) if row.outcome == Affected =>
        match prior {
          None => true
          Some(previous) => previous.outcome != Affected
        }
      _ => false
    }
    let missing = match (prior, now) {
      (Some(row), None) =>
        row.advisory is Some(_) ||
        !current_identities.contains(package_key(row.item))
      _ => false
    }
    entries.push({
      category,
      before: prior,
      after: now,
      causes,
      new_hit,
      missing,
    })
  }
  (entries, identities)
}

///|
/// 1: newly affected; 3: current incomplete evidence, removed evidence or identity
/// substitution; 0: neither. Existing positives remain in current_exit_code.
pub fn Changes::exit_code(self : Changes) -> Int32 {
  if self.entries.any(e => e.new_hit) {
    return 1
  }
  if self.before.assessment.snapshot.crates_io !=
    self.after.assessment.snapshot.crates_io ||
    !self.identities.is_empty() ||
    !self.after.assessment.unscoped.is_empty() ||
    self.after.assessment.decisions.any(d => d.incomplete) ||
    self.entries.any(e => e.missing) {
    return 3
  }
  0
}

///|
pub fn Changes::to_json(self : Changes) -> Json {
  let view : Json = {
    "schema_version": 1,
    "scope": Json(
      "assessment changes, not a safety verdict or vulnerability waiver",
    ),
    "exit_code": Json(self.exit_code()),
    "before_delivery": Json(self.before.digest),
    "current_delivery": Json(self.after.digest),
    "before_exit_code": Json(self.before.assessment.exit_code()),
    "current_exit_code": Json(self.after.assessment.exit_code()),
    "identity_changes": Json(
      self.identities.map(pair => {
        "before": pair.0.to_json(),
        "after": pair.1.to_json(),
      }),
    ),
    "entries": Json(
      self.entries.map(e => {
        "category": Json(e.category),
        "causes": Json(e.causes),
        "newly_affected": Json(e.new_hit),
        "missing_evidence": Json(e.missing),
        "before": match e.before {
          None => Json::null()
          Some(row) => row.to_json()
        },
        "after": match e.after {
          None => Json::null()
          Some(row) => row.to_json()
        },
      }),
    ),
  }
  evaluation_changes(
    view,
    self.before.assessment.snapshot,
    self.after.assessment.snapshot,
  )
}

///|
fn evaluation_changes(view : Json, before : Snapshot, after : Snapshot) -> Json {
  if (before.crates_io || after.crates_io) && view is Object(fields) {
    fields["evaluation_profile_changed"] = Json(
      before.crates_io != after.crates_io,
    )
    fields["before_evaluation_profile"] = Json(before.evaluation_label())
    fields["current_evaluation_profile"] = Json(after.evaluation_label())
  }
  view
}
