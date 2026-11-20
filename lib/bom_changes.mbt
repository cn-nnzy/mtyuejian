///|
priv struct ComponentChange {
  category : String
  before : UnresolvedComponent?
  after : UnresolvedComponent?
  resolved : Package?
}

///|
pub struct BomChanges {
  priv before : BomDelivery
  priv after : BomDelivery
  priv entries : Array[ChangeEntry]
  priv identities : Array[(Package, Package)]
  priv components : Array[ComponentChange]
}

///|
fn unresolved_json(row : UnresolvedComponent) -> Json {
  {
    "path": Json(row.path),
    "id": match row.id {
      None => Json::null()
      Some(id) => Json(id)
    },
    "code": Json(row.code),
  }
}

///|
fn unresolved_key(profile : String, row : UnresolvedComponent) -> String {
  Json([
    Json(profile),
    Json(
      if row.code == "external-document-not-expanded" {
        "external-document"
      } else {
        "component"
      },
    ),
    Json(if row.id is Some(_) { "id" } else { "pointer" }),
    Json(row.id.unwrap_or(row.path)),
  ]).stringify()
}

///|
fn resolved_view(result : BomAssessment) -> Assessment {
  result.result.unwrap_or({
    decisions: [],
    unscoped: [],
    snapshot: result.snapshot,
  })
}

///|
/// Compare verified full receipts. Removed unresolved evidence and input-profile
/// changes require review even when the current version assessment is complete.
pub fn compare_bom_deliveries(
  before : BomDelivery,
  after : BomDelivery,
) -> BomChanges {
  let (entries, identities) = decision_changes(
    resolved_view(before.result),
    resolved_view(after.result),
  )
  let old = Map([])
  let current = Map([])
  let packages = Map([])
  let keys = []
  for row in before.result.imported.unresolved {
    let key = unresolved_key(before.result.imported.profile, row)
    old[key] = row
    keys.push(key)
  }
  for row in after.result.imported.unresolved {
    let key = unresolved_key(after.result.imported.profile, row)
    current[key] = row
    if !old.contains(key) {
      keys.push(key)
    }
  }
  for item in after.result.imported.packages {
    packages[item.id] = item
  }
  keys.sort_by(text_order)
  let components = keys.map(key => {
    let prior = old.get(key)
    let now = current.get(key)
    let resolved = match prior {
      Some(row) if before.result.imported.profile ==
        after.result.imported.profile =>
        match row.id {
          Some(id) => packages.get(id)
          None => None
        }
      _ => None
    }
    let category = match (prior, now) {
      (None, Some(_)) => "added-unresolved"
      (Some(_), None) =>
        if resolved is Some(_) {
          "identity-resolved"
        } else {
          "removed-unresolved"
        }
      (Some(a), Some(b)) =>
        if unresolved_json(a) == unresolved_json(b) {
          "unchanged-unresolved"
        } else {
          "changed-unresolved"
        }
      _ => "unchanged-unresolved"
    }
    { category, before: prior, after: now, resolved, }
  })
  { before, after, entries, identities, components, }
}

///|
pub fn BomChanges::exit_code(self : BomChanges) -> Int32 {
  if self.entries.any(e => e.new_hit) {
    return 1
  }
  let current = resolved_view(self.after.result)
  if self.before.result.imported.profile != self.after.result.imported.profile ||
    !self.identities.is_empty() ||
    !self.after.result.imported.unresolved.is_empty() ||
    !current.unscoped.is_empty() ||
    current.decisions.any(d => d.incomplete) ||
    self.entries.any(e => e.missing) ||
    self.components.any(c => c.before is Some(_) && c.after is None) {
    return 3
  }
  0
}

///|
pub fn BomChanges::to_json(self : BomChanges) -> Json {
  {
    "schema_version": 1,
    "scope": Json(
      "BOM assessment changes; removed unknown evidence requires review; not a safety verdict",
    ),
    "exit_code": Json(self.exit_code()),
    "before_delivery": Json(self.before.digest),
    "current_delivery": Json(self.after.digest),
    "before_exit_code": Json(self.before.result.exit_code()),
    "current_exit_code": Json(self.after.result.exit_code()),
    "profile_changed": Json(
      self.before.result.imported.profile != self.after.result.imported.profile,
    ),
    "bom_source_changed": Json(
      self.before.result.imported.raw != self.after.result.imported.raw ||
      self.before.result.imported.origin != self.after.result.imported.origin,
    ),
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
    "component_changes": Json(
      self.components.map(c => {
        "category": Json(c.category),
        "before": match c.before {
          None => Json::null()
          Some(row) => unresolved_json(row)
        },
        "after": match c.after {
          None => Json::null()
          Some(row) => unresolved_json(row)
        },
        "current_package": match c.resolved {
          None => Json::null()
          Some(item) => item.to_json()
        },
      }),
    ),
  }
}
