///|
fn coverage_advice(code : String) -> (String, String, String) {
  match code {
    "no-matching-advisory" =>
      (
        "missing_advisory", "No supplied record matches this exact package identity.",
        "Obtain a reviewed OSV record for this ecosystem and name. An absent record is not a negative result.",
      )
    "unsupported-range" | "git-tags-not-package-versions" =>
      (
        "unsupported_version_rule", "Version evidence uses unsupported range or Git-tag semantics.",
        "Review the original range and use a tool supporting its ecosystem or Git rules. Keep this decision incomplete.",
      )
    "query-is-not-semver" =>
      (
        "version_syntax", "The installed version cannot be ordered as strict SemVer.",
        "Verify the original installed version and select an appropriate ecosystem comparator; do not coerce the spelling.",
      )
    "withdrawn-record" =>
      (
        "withdrawn_advisory", "The matching source record is withdrawn.", "Review the withdrawal and obtain an active source record. Do not treat withdrawal as proof of non-impact.",
      )
    "missing-version-evidence" =>
      (
        "missing_version_evidence", "A matching entry supplies no usable version evidence.",
        "Obtain ranges or affected versions from the advisory publisher and retain the original entry for review.",
      )
    "package-identity-missing" =>
      (
        "missing_identity", "An active advisory entry has no complete package identity.",
        "Review the source entry and obtain an explicit ecosystem and name; do not guess identity from prose.",
      )
    "component-name-conflict"
    | "component-version-conflict"
    | "purl-category-conflict"
    | "ambiguous-purl" =>
      (
        "identity_conflict", "The BOM contains conflicting or ambiguous identity evidence.",
        "Correct the identity at the BOM producer, regenerate the document and review the change against the retained source.",
      )
    "missing-bom-ref" | "missing-spdx-id" | "missing-purl" =>
      (
        "missing_identity", "This BOM entry lacks identity required by the Cargo profile.",
        "Ask the producer for a unique entry ID and a Cargo PURL consistent with name and version. Retain unresolved entries.",
      )
    "purl-outside-cargo-profile" | "cargo-namespace-not-supported" =>
      (
        "unsupported_identity", "This identity is outside the documented Cargo PURL profile.",
        "Inspect the PURL and registry origin. Use a supported consumer for other ecosystems or qualifiers; do not rewrite identity to force acceptance.",
      )
    "unsupported-component-type" =>
      (
        "unsupported_component", "This component type is outside the package assessment profile.",
        "Review the component role and use a suitable assessment tool. Keep this node in the outer completeness gate.",
      )
    "external-document-not-expanded" =>
      (
        "external_inventory", "An external SPDX document has not been expanded.",
        "Obtain and separately assess the referenced document from a trusted source. This tool does not retrieve it automatically.",
      )
    "no-packages" | "no-components" =>
      (
        "empty_inventory", "The BOM supplies no assessable inventory entries.", "Regenerate a complete inventory from the actual project; an empty document cannot establish non-impact.",
      )
    _ =>
      (
        "other", "Retained evidence requires manual review.", "Inspect the original source and diagnostic code with a compatible consumer. Do not suppress the evidence.",
      )
  }
}

///|
fn coverage_diagnostic(
  code : String,
  source : Json,
  id : String?,
  report_pointer : String,
  kind? : String,
) -> Json {
  let (category, message, next_action) = coverage_advice(code)
  let artifact = (
      code == "unsupported-component-type" || code == "missing-purl"
    ) &&
    (kind == Some("file") || kind == Some("FILE"))
  {
    "category": Json(if artifact { "artifact_node" } else { category }),
    "code": Json(code),
    "source": source,
    "package_id": match id {
      None => Json::null()
      Some(id) => Json(id)
    },
    "report_pointer": Json(report_pointer),
    "component_kind": match kind {
      None => Json::null()
      Some(kind) => Json(kind)
    },
    "message": Json(
      if artifact {
        "A file or directory artifact is outside the Cargo package profile."
      } else {
        message
      },
    ),
    "next_action": Json(
      if artifact {
        "Review this artifact separately. Its presence remains incomplete; do not delete it to obtain a passing verdict."
      } else {
        next_action
      },
    ),
  }
}

///|
fn coverage_view(
  result : Assessment,
  unresolved : Array[UnresolvedComponent],
  input_profile : String,
  origin : String,
  assessment_pointer : String,
) -> Json {
  let by_package : Map[String, Array[Int32]] = Map([])
  let documents : Map[String, Advisory] = Map([])
  for document in result.snapshot.documents {
    documents[document.id] = document
  }
  let ids = []
  let diagnostics = []
  let base = assessment_pointer + "/decisions/"
  for i, decision in result.decisions {
    if by_package.get(decision.item.id) is Some(indices) {
      indices.push(i)
    } else {
      by_package[decision.item.id] = [i]
      ids.push(decision.item.id)
    }
    for j, evidence in decision.evidence {
      let (category, _, _) = coverage_advice(evidence.code)
      if category == "other" {
        continue
      }
      let record = match decision.advisory {
        None => None
        Some(id) => documents.get(id)
      }
      let source : Json = match record {
        None =>
          {
            "kind": "inventory",
            "origin": Json(origin),
            "path": Json::null(),
            "advisory": Json::null(),
          }
        Some(record) =>
          {
            "kind": "advisory",
            "origin": Json(record.origin),
            "path": Json(evidence.path),
            "advisory": Json(record.id),
          }
      }
      diagnostics.push(
        coverage_diagnostic(
          evidence.code,
          source,
          Some(decision.item.id),
          base + i.to_string() + "/evidence/" + j.to_string(),
        ),
      )
    }
  }
  ids.sort_by(text_order)
  let counts : Map[String, Int32] = {
    "resolved_packages": ids.length(),
    "known_match_packages": 0,
    "not_matched_packages": 0,
    "undetermined_packages": 0,
    "no_advisory_packages": 0,
    "packages_with_incomplete_evidence": 0,
    "unresolved_entries": unresolved.length(),
    "unscoped_advisory_entries": result.unscoped.length(),
    "decision_rows": result.decisions.length(),
    "advisory_documents": result.snapshot.documents.length(),
  }
  let packages = []
  for id in ids {
    let indices = by_package[id]
    let decisions = indices.map(i => result.decisions[i])
    let incomplete = decisions.any(d => d.incomplete)
    let status = if decisions.any(d => d.outcome == Affected) {
      "known_match"
    } else if decisions.all(d => d.outcome == NoAdvisory) {
      "no_advisory"
    } else if incomplete {
      "undetermined"
    } else {
      "not_matched"
    }
    counts[status + "_packages"] += 1
    if incomplete {
      counts["packages_with_incomplete_evidence"] += 1
    }
    packages.push({
      "package": decisions[0].item.to_json(),
      "status": Json(status),
      "incomplete": Json(incomplete),
      "decision_indices": Json(indices),
    })
  }
  for i, (advisory, path) in result.unscoped {
    let record = documents.get(advisory)
    diagnostics.push(
      coverage_diagnostic(
        "package-identity-missing",
        {
          "kind": "advisory",
          "origin": Json(record.map(d => d.origin).unwrap_or("memory")),
          "path": Json(path),
          "advisory": Json(advisory),
        },
        None,
        assessment_pointer + "/unscoped_entries/" + i.to_string(),
      ),
    )
  }
  for i, row in unresolved {
    let source : Json = {
      "kind": "bom",
      "origin": Json(origin),
      "path": Json(row.path),
      "role": Json(
        if row.path == "/metadata/component" {
          "bom_subject"
        } else if row.code == "external-document-not-expanded" {
          "external_document"
        } else {
          "entry"
        },
      ),
    }
    let diagnostic = match row.component_kind {
      None =>
        coverage_diagnostic(
          row.code,
          source,
          row.id,
          "/import/unresolved/" + i.to_string(),
        )
      Some(kind) =>
        coverage_diagnostic(
          row.code,
          source,
          row.id,
          "/import/unresolved/" + i.to_string(),
          kind~,
        )
    }
    diagnostics.push(diagnostic)
  }
  let categories : Map[String, Int32] = Map([])
  for diagnostic in diagnostics {
    if diagnostic is { "category": String(category), .. } {
      categories[category] = categories.get(category).unwrap_or(0) + 1
    }
  }
  let code = if result.exit_code() == 1 {
    1
  } else if !unresolved.is_empty() {
    3
  } else {
    result.exit_code()
  }
  {
    "schema_version": 1,
    "profile": "coverage-review-v1",
    "scope": "supplied inventory and advisory snapshot only; counts are not a safety score or unique vulnerability count",
    "input_profile": Json(input_profile),
    "assessment_pointer": Json(assessment_pointer),
    "exit_code": Json(code),
    "counts": Json(counts),
    "diagnostic_counts": Json(categories),
    "packages": Json(packages),
    "diagnostics": Json(diagnostics),
  }
}

///|
/// Package-level coverage and actionable incomplete-evidence diagnostics. This
/// independent view does not change the assessment, receipt wire format or gate.
pub fn Assessment::coverage(self : Assessment) -> Json {
  coverage_view(self, [], "inventory-v1", "caller inventory", "")
}

///|
/// Include every unresolved BOM entry and retain the outer completeness gate.
/// File/directory artifacts remain incomplete, with a distinct diagnostic category.
pub fn BomAssessment::coverage(self : BomAssessment) -> Json {
  coverage_view(
    resolved_view(self),
    self.imported.unresolved,
    self.imported.profile,
    self.imported.origin,
    "/assessment",
  )
}
