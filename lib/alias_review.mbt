///|
fn alias_root(parents : Array[Int32], index : Int32) -> Int32 {
  let mut current = index
  while parents[current] != current {
    current = parents[current]
  }
  current
}

///|
fn alias_review_view(
  snapshot : Snapshot,
  decisions : Array[Decision],
  report : Json,
  code : Int32,
  assessment_pointer : String,
) -> Json {
  let parents = Array::makei(snapshot.documents.length(), i => i)
  let owners : Map[String, Array[Int32]] = Map([])
  let primaries = Map([])
  for index, doc in snapshot.documents {
    primaries[doc.id] = index
    let seen : Map[String, Unit] = Map([])
    for identifier in [doc.id] + doc.aliases {
      if seen.contains(identifier) {
        continue
      }
      seen[identifier] = ()
      match owners.get(identifier) {
        None => owners[identifier] = [index]
        Some(indices) => {
          let first = alias_root(parents, indices[0])
          let current = alias_root(parents, index)
          if first < current {
            parents[current] = first
          } else if current < first {
            parents[first] = current
          }
          indices.push(index)
        }
      }
    }
  }
  let records : Map[Int32, Array[Int32]] = Map([])
  for index in 0..<snapshot.documents.length() {
    let root = alias_root(parents, index)
    match records.get(root) {
      None => records[root] = [index]
      Some(indices) => indices.push(index)
    }
  }
  let roots = records.keys().collect()
  roots.sort()
  let identifiers = owners.keys().collect()
  identifiers.sort_by(text_order)
  let assigned : Map[Int32, Unit] = Map([])
  let groups = roots.map(root => {
    let indices = records[root]
    let labels = identifiers.filter(label => {
      alias_root(parents, owners[label][0]) == root
    })
    let matched = []
    for i, decision in decisions {
      if decision.advisory is Some(id) &&
        primaries.get(id) is Some(owner) &&
        alias_root(parents, owner) == root {
        matched.push(i)
        assigned[i] = ()
      }
    }
    let unscoped = []
    for index in indices {
      let doc = snapshot.documents[index]
      if !doc.withdrawn {
        for i, entry in doc.affected {
          if entry.ecosystem is None || entry.name is None {
            unscoped.push({
              "record_index": Json(index),
              "path": Json("/affected/" + i.to_string()),
            })
          }
        }
      }
    }
    {
      "records": Json(
        indices.map(index => {
          let doc = snapshot.documents[index]
          {
            "snapshot_index": Json(index),
            "id": Json(doc.id),
            "origin": Json(doc.origin),
            "modified": Json(doc.modified),
            "withdrawn": Json(doc.withdrawn),
          }
        }),
      ),
      "identifiers": Json(labels),
      "links": Json(
        labels
        .filter(label => owners[label].length() > 1)
        .map(label => {
          "identifier": Json(label),
          "record_indices": Json(owners[label]),
        }),
      ),
      "decision_indices": Json(matched),
      "unscoped_entries": Json(unscoped),
      "has_scoped_decisions": Json(!matched.is_empty()),
      "has_known_match": Json(
        matched.any(i => decisions[i].outcome == Affected),
      ),
      "has_incomplete_evidence": Json(
        !unscoped.is_empty() || matched.any(i => decisions[i].incomplete),
      ),
    }
  })
  let unassigned = []
  for i in 0..<decisions.length() {
    if !assigned.contains(i) {
      unassigned.push(i)
    }
  }
  {
    "schema_version": 1,
    "profile": Json("alias-review-v1"),
    "scope": Json(
      "declared identifier links; source correlation only; no decision merging or vulnerability-count claim",
    ),
    "exit_code": Json(code),
    "assessment_pointer": Json(assessment_pointer),
    "groups": Json(groups),
    "unassigned_decision_indices": Json(unassigned),
    "report": report,
    "snapshot": snapshot.to_json(),
  }
}

///|
/// Correlate declared OSV aliases while retaining every decision, source and gate.
/// Group indices refer to the complete report/snapshot included in this view.
pub fn Delivery::alias_review(self : Delivery) -> Json {
  alias_review_view(
    self.assessment.snapshot,
    self.assessment.decisions,
    self.assessment.to_json(),
    self.assessment.exit_code(),
    "",
  )
}

///|
/// Review all advisory identifiers even when the full BOM has no resolved package.
/// Unsupported component evidence remains in the original outer report.
pub fn BomDelivery::alias_review(self : BomDelivery) -> Json {
  let decisions = match self.result.result {
    None => []
    Some(result) => result.decisions
  }
  alias_review_view(
    self.result.snapshot,
    decisions,
    self.result.to_json(),
    self.result.exit_code(),
    "/assessment",
  )
}
