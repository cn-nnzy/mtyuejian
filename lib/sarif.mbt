///|
fn sarif_uri(uri : String) -> String raise InputError {
  nonempty(uri, "/artifact_uri") |> ignore
  if uri.has_prefix("/") ||
    uri.split("/").any(part => part.is_empty() || part == "." || part == "..") ||
    !uri
    .code_units()
    .all(c => {
      (c >= 48 && c <= 57) ||
      (c >= 65 && c <= 90) ||
      (c >= 97 && c <= 122) ||
      c == 45 ||
      c == 46 ||
      c == 47 ||
      c == 95 ||
      c == 126
    }) {
    reject(
      "invalid-artifact-uri", "/artifact_uri", "Use a relative URI with ASCII letters, digits, -._~/; no empty, dot or parent segments",
    )
  }
  uri
}

///|
fn sarif_identity(parts : Array[Json]) -> @sarif.Fingerprint {
  let bytes = @utf8.encode(
    "yuejian-sarif-identity-v1\n" + Json(parts).stringify(),
  )
  @sarif.Fingerprint(
    "yuejian/identity/v1",
    @hex.encode(Bytes::from_array(@crypto.sha256(bytes)[:])[:]),
  )
}

///|
fn sarif_builder(uri : String) -> @sarif.SarifBuilder {
  let builder = @sarif.SarifBuilder(
    "Yuejian",
    tool_version="0.1.0",
    information_uri="https://github.com/cn-nnzy/mtyuejian",
  )
  builder.set_automation_id("yuejian/offline-version-evidence")
  builder.add_artifact(uri, mime_type="application/json", roles=[
    "analysisTarget",
  ])
  |> ignore
  builder.add_rule(
    "YJ001",
    name="VersionMatch",
    short_description="Installed version evidence in the supplied OSV snapshot",
    default_level="error",
    tags=["security", "version-evidence"],
  )
  |> ignore
  builder.add_rule(
    "YJ002",
    name="EvidenceCompleteness",
    short_description="Assessment requires complete identity and version evidence",
    default_level="warning",
    tags=["evidence-completeness"],
  )
  |> ignore
  builder.add_rule(
    "YJ003",
    name="BomIdentity",
    short_description="Every listed BOM component requires a supported package identity",
    default_level="warning",
    tags=["inventory-completeness"],
  )
  |> ignore
  builder.add_invocation(execution_successful=true)
  builder
}

///|
fn sarif_location(uri : String) -> @sarif.SarifLocation {
  @sarif.SarifLocation(
    // Artifact-only location: no source line or column is inferred from a JSON view.
    @sarif.PhysicalLocation(@sarif.ArtifactLocation(uri, index=0)),
  )
}

///|
fn append_sarif_assessment(
  builder : @sarif.SarifBuilder,
  result : Assessment,
  uri : String,
  source : SourceLocations?,
) -> Unit {
  for decision in result.decisions {
    let item = decision.item
    let advisory = match decision.advisory {
      Some(id) => Json(id)
      None => Json::null()
    }
    let parts = [Json(item.id), Json(item.ecosystem), Json(item.name), advisory]
    let properties = [
      @sarif.SarifProperty("yuejian/decision", decision.to_json().stringify()),
      @sarif.SarifProperty("yuejian/outcome", decision.outcome.label()),
    ]
    let subject = item.ecosystem +
      "/" +
      item.name +
      "@" +
      item.version +
      " (" +
      item.id +
      ")"
    if decision.outcome == Affected || decision.outcome == NotMatched {
      let hit = decision.outcome == Affected
      let relation = if hit {
        ": version matches supplied advisory "
      } else {
        ": version not matched by supplied advisory "
      }
      builder.add_result_object(
        @sarif.SarifResult(
          "YJ001",
          subject + relation + decision.advisory.unwrap_or(""),
          kind=if hit { "fail" } else { "pass" },
          level=if hit { "error" } else { "none" },
          locations=[package_location(uri, source, item.id)],
          properties~,
          fingerprints=[sarif_identity([Json("YJ001")] + parts)],
        ),
      )
      |> ignore
    }
    if decision.incomplete {
      builder.add_result_object(
        @sarif.SarifResult(
          "YJ002",
          subject +
          ": incomplete evidence (" +
          decision.outcome.label() +
          "); review the attached decision",
          level="warning",
          properties~,
          locations=[package_location(uri, source, item.id)],
          fingerprints=[sarif_identity([Json("YJ002")] + parts)],
        ),
      )
      |> ignore
    }
  }
  for (advisory, path) in result.unscoped {
    builder.add_result_object(
      @sarif.SarifResult(
        "YJ002",
        advisory + ": advisory entry lacks package identity at " + path,
        level="warning",
        properties=[
          @sarif.SarifProperty("yuejian/advisory", advisory),
          @sarif.SarifProperty("yuejian/evidence_pointer", path),
        ],
        fingerprints=[
          sarif_identity([Json("unscoped"), Json(advisory), Json(path)]),
        ],
      ),
    )
    |> ignore
  }
}

///|
fn finish_sarif(
  builder : @sarif.SarifBuilder,
  report : Json,
  snapshot : Snapshot,
  code : Int32,
  source : SourceLocations?,
) -> Json raise InputError {
  let log = builder.log()
  let policy = @sarif.SarifValidationPolicy(
    require_results_have_locations=false,
    require_declared_rules=true,
    require_artifacts_for_locations=true,
  )
  let diagnostics = log.validate_with_policy(policy)
  if !diagnostics.is_empty() {
    reject(
      "sarif-encoding",
      "",
      "Internal SARIF projection failed validation: " +
      @sarif.diagnostics_report(diagnostics),
    )
  }
  let output = log.to_json()
  guard output is { "runs": Array([Object(run)]), .. } else {
    reject("sarif-encoding", "/runs", "Internal SARIF run is missing")
    return Json::null()
  }
  run["properties"] = {
    "yuejian/profile": Json("assessment-sarif-v1"),
    "yuejian/exit_code": Json(code),
    "yuejian/report": report,
    "yuejian/snapshot": snapshot.to_json(),
  }
  run["columnKind"] = Json("utf16CodeUnits")
  if source is Some(source) {
    run["newlineSequences"] = Json(["\r\n", "\n", "\r"])
    guard run["properties"] is Object(properties) else {
      reject(
        "sarif-encoding", "/runs/0/properties", "Internal properties are missing",
      )
      return output
    }
    properties["yuejian/location_source"] = Json(source.raw)
  }
  output
}

///|
/// Project all decisions and incomplete evidence to SARIF 2.1.0. The caller
/// supplies the inventory artifact's relative URI; source coordinates are not
/// invented. Original report and advisory snapshot remain in run properties.
/// Supply inventory_source to bind actual input and emit UTF-16 source regions.
pub fn Assessment::to_sarif(
  self : Assessment,
  inventory_uri~ : String,
  inventory_source? : String,
) -> Json raise InputError {
  let uri = sarif_uri(inventory_uri)
  let builder = sarif_builder(uri)
  let source = inventory_source.map(raw => inventory_locations(self, raw))
  append_sarif_assessment(builder, self, uri, source)
  finish_sarif(builder, self.to_json(), self.snapshot, self.exit_code(), source)
}

///|
/// Export the outer BOM gate as well as known decisions. Unresolved components
/// become explicit warnings; original BOM text is retained in run properties.
/// Set locate=true to index that exact retained source, including unresolved rows.
pub fn BomAssessment::to_sarif(
  self : BomAssessment,
  bom_uri~ : String,
  locate~ : Bool = false,
) -> Json raise InputError {
  let uri = sarif_uri(bom_uri)
  let builder = sarif_builder(uri)
  let source = if locate { Some(bom_locations(self.imported)) } else { None }
  if self.result is Some(result) {
    append_sarif_assessment(builder, result, uri, source)
  }
  for row in self.imported.unresolved {
    let identity = match row.id {
      None => [Json("pointer"), Json(row.path)]
      Some(id) => [Json("id"), Json(id)]
    }
    builder.add_result_object(
      @sarif.SarifResult(
        "YJ003",
        "BOM component at " + row.path + ": " + row.code,
        level="warning",
        locations=[indexed_location(uri, source, Some(row.path))],
        properties=[
          @sarif.SarifProperty("yuejian/component_pointer", row.path),
          @sarif.SarifProperty("yuejian/code", row.code),
        ],
        fingerprints=[sarif_identity([Json("component")] + identity)],
      ),
    )
    |> ignore
  }
  finish_sarif(builder, self.to_json(), self.snapshot, self.exit_code(), source)
}
