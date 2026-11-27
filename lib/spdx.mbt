///|
fn spdx_id(id : String, prefix : String) -> Bool {
  id.has_prefix(prefix) &&
  id.length() > prefix.length() &&
  id[prefix.length():]
  .code_units()
  .all(c => {
    (c >= 48 && c <= 57) ||
    (c >= 65 && c <= 90) ||
    (c >= 97 && c <= 122) ||
    c == 45 ||
    c == 46
  })
}

///|
/// Project all SPDX 2.3 packages onto the same restricted Cargo identity profile
/// as CycloneDX. External document inventories remain unresolved, never omitted.
pub fn read_spdx(
  input : String,
  origin~ : String = "memory",
) -> BomImport raise InputError {
  let fields = object(read_value(input), "")
  if string_field(fields, "spdxVersion", "") != "SPDX-2.3" {
    reject("unsupported-spdx-version", "/spdxVersion", "Expected SPDX-2.3 JSON")
  }
  if string_field(fields, "SPDXID", "") != "SPDXRef-DOCUMENT" {
    reject("invalid-document-id", "/SPDXID", "Expected SPDXRef-DOCUMENT")
  }
  let packages = []
  let unresolved = []
  let ids : Map[String, Unit] = Map([])
  for i, value in optional_list(fields, "packages", "", 1024) {
    let path = "/packages/" + i.to_string()
    let item = object(value, path)
    let id = optional_text(item, "SPDXID", path)
    if id is Some(id) {
      if !spdx_id(id, "SPDXRef-") || id == "SPDXRef-DOCUMENT" {
        reject(
          "invalid-spdx-id",
          pointer(path, "SPDXID"),
          "Expected a non-document SPDXRef- identifier containing letters, digits, . or -",
        )
      }
      if ids.contains(id) {
        reject(
          "duplicate-spdx-id",
          pointer(path, "SPDXID"),
          "Package SPDX identifiers must be unique",
        )
      }
      ids[id] = ()
    }
    let name = optional_component_name(item, path)
    let version = optional_text(item, "versionInfo", path)
    // Diagnostic metadata must not change admission of an otherwise opaque field.
    let component_kind = match item.get("primaryPackagePurpose") {
      Some(Text(kind)) => Some(kind)
      _ => None
    }
    let purls = []
    for j, external in optional_list(item, "externalRefs", path, 64) {
      let ref_path = pointer(pointer(path, "externalRefs"), j.to_string())
      let external = object(external, ref_path)
      let kind = string_field(external, "referenceType", ref_path)
      let category = string_field(external, "referenceCategory", ref_path)
      let locator = string_field(external, "referenceLocator", ref_path)
      if kind == "purl" {
        purls.push((category, locator))
      }
    }
    let issue = if id is None {
      Some("missing-spdx-id")
    } else if purls.is_empty() {
      Some("missing-purl")
    } else if purls.length() != 1 {
      Some("ambiguous-purl")
    } else if purls[0].0 != "PACKAGE-MANAGER" {
      Some("purl-category-conflict")
    } else {
      match cargo_purl(purls[0].1) {
        None => Some("purl-outside-cargo-profile")
        Some((purl_name, purl_version)) =>
          if name != Some(purl_name) {
            Some("component-name-conflict")
          } else if version != Some(purl_version) {
            Some("component-version-conflict")
          } else {
            match id {
              Some(id) => {
                packages.push(
                  Package::new(
                    id~,
                    ecosystem="crates.io",
                    name=purl_name,
                    version=purl_version,
                  ),
                )
                None
              }
              None => Some("missing-spdx-id")
            }
          }
      }
    }
    if issue is Some(code) {
      unresolved.push({ path, id, code, component_kind, })
    }
  }
  for i, value in optional_list(fields, "externalDocumentRefs", "", 64) {
    let path = "/externalDocumentRefs/" + i.to_string()
    let external = object(value, path)
    let id = optional_text(external, "externalDocumentId", path)
    if id is Some(id) {
      if !spdx_id(id, "DocumentRef-") || ids.contains(id) {
        reject(
          "invalid-external-document-id",
          pointer(path, "externalDocumentId"),
          "External document IDs must be unique DocumentRef- identifiers",
        )
      }
      ids[id] = ()
    }
    unresolved.push({
      path,
      id,
      code: "external-document-not-expanded",
      component_kind: None,
    })
  }
  if packages.is_empty() && unresolved.is_empty() {
    unresolved.push({
      path: "/packages",
      id: None,
      code: "no-packages",
      component_kind: None,
    })
  }
  packages.sort_by((a, b) => text_order(a.id, b.id))
  {
    profile: "spdx-cargo-v1",
    raw: input,
    origin: nonempty(origin, "/origin"),
    packages,
    unresolved,
  }
}

///|
/// Detect an unambiguous CycloneDX or SPDX header, then apply its inventory profile.
pub fn read_bom(
  input : String,
  origin~ : String = "memory",
) -> BomImport raise InputError {
  let fields = object(read_value(input), "")
  match (fields.contains("bomFormat"), fields.contains("spdxVersion")) {
    (true, false) => read_cyclonedx(input, origin~)
    (false, true) => read_spdx(input, origin~)
    _ => {
      reject(
        "ambiguous-bom-format", "", "Provide exactly one CycloneDX bomFormat or SPDX spdxVersion header",
      )
      read_spdx(input, origin~)
    }
  }
}
