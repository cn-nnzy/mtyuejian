///|
priv struct UnresolvedComponent {
  path : String
  id : String?
  code : String
}

///|
/// A lossless source plus a bounded Cargo-PURL inventory projection. Unresolved
/// components remain explicit and prevent exporting a complete inventory.
pub struct BomImport {
  priv profile : String
  priv raw : String
  priv origin : String
  priv packages : Array[Package]
  priv unresolved : Array[UnresolvedComponent]
}

///|
pub struct BomAssessment {
  priv imported : BomImport
  priv result : Assessment?
  priv snapshot : Snapshot
}

///|
fn optional_text(
  fields : Map[String, Value],
  key : String,
  path : String,
) -> String? raise InputError {
  match fields.get(key) {
    None => None
    Some(value) =>
      Some(nonempty(text(value, pointer(path, key)), pointer(path, key)))
  }
}

///|
fn cargo_purl(value : String) -> (String, String)? {
  if !value.has_prefix("pkg:cargo/") ||
    value.contains("%") ||
    value.contains("?") ||
    value.contains("#") {
    return None
  }
  guard value[10:].split_once("@") is Some((name, version)) else { return None }
  let name = name.to_owned()
  let version = version.to_owned()
  if name.is_empty() ||
    !name
    .code_units()
    .all(c => {
      (c >= 48 && c <= 57) ||
      (c >= 65 && c <= 90) ||
      (c >= 97 && c <= 122) ||
      c == 45 ||
      c == 95
    }) {
    return None
  }
  guard parse_version(version) is Some(_) else { return None }
  Some((name, version))
}

///|
fn import_component(
  value : Value,
  path : String,
  depth : Int32,
  ids : Map[String, Unit],
  packages : Array[Package],
  unresolved : Array[UnresolvedComponent],
  count : Ref[Int32],
) -> Unit raise InputError {
  count.val += 1
  if depth > 16 || count.val > 1024 {
    reject(
      "bom-component-limit", path, "At most 1024 components and 16 nested component levels are supported",
    )
  }
  let fields = object(value, path)
  let id = optional_text(fields, "bom-ref", path)
  if id is Some(id) {
    if ids.contains(id) {
      reject(
        "duplicate-bom-ref",
        pointer(path, "bom-ref"),
        "Component references must be globally unique",
      )
    }
    ids[id] = ()
  }
  let kind = optional_text(fields, "type", path)
  let name = optional_text(fields, "name", path)
  let version = optional_text(fields, "version", path)
  let purl = optional_text(fields, "purl", path)
  let group = optional_text(fields, "group", path)
  let issue = if id is None {
    Some("missing-bom-ref")
  } else if kind != Some("library") &&
    kind != Some("application") &&
    kind != Some("framework") {
    Some("unsupported-component-type")
  } else if group is Some(_) {
    Some("cargo-namespace-not-supported")
  } else {
    match purl {
      None => Some("missing-purl")
      Some(purl) =>
        match cargo_purl(purl) {
          None => Some("purl-outside-cargo-profile")
          Some((purl_name, purl_version)) =>
            if name != Some(purl_name) {
              Some("component-name-conflict")
            } else if version != Some(purl_version) {
              Some("component-version-conflict")
            } else {
              guard id is Some(id) else { return }
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
        }
    }
  }
  if issue is Some(code) {
    unresolved.push({ path, id, code, })
  }
  for i, child in optional_list(fields, "components", path, 1024) {
    import_component(
      child,
      pointer(pointer(path, "components"), i.to_string()),
      depth + 1,
      ids,
      packages,
      unresolved,
      count,
    )
  }
}

///|
/// Read CycloneDX 1.5/1.6 components, nested components and metadata.component.
/// This is an inventory adapter, not a full CycloneDX validator or graph analyzer.
pub fn read_cyclonedx(
  input : String,
  origin~ : String = "memory",
) -> BomImport raise InputError {
  let fields = object(read_value(input), "")
  if text(required(fields, "bomFormat", ""), "/bomFormat") != "CycloneDX" {
    reject("unsupported-bom", "/bomFormat", "Expected CycloneDX")
  }
  let version = string_field(fields, "specVersion", "")
  if version != "1.5" && version != "1.6" {
    reject(
      "unsupported-bom-version", "/specVersion", "Supported CycloneDX versions are 1.5 and 1.6",
    )
  }
  if fields.get("version") is Some(value) {
    guard value is Number(token) && decimal(token) && !token.has_prefix("0") else {
      reject(
        "invalid-bom-version", "/version", "Expected a positive decimal integer token",
      )
    }
  }
  let packages = []
  let unresolved = []
  let ids = Map([])
  let count = Ref(0)
  if fields.get("metadata") is Some(metadata) {
    let metadata = object(metadata, "/metadata")
    if metadata.get("component") is Some(value) {
      import_component(
        value, "/metadata/component", 1, ids, packages, unresolved, count,
      )
    }
  }
  for i, value in optional_list(fields, "components", "", 1024) {
    import_component(
      value,
      "/components/" + i.to_string(),
      1,
      ids,
      packages,
      unresolved,
      count,
    )
  }
  if count.val == 0 {
    unresolved.push({ path: "/components", id: None, code: "no-components", })
  }
  packages.sort_by((a, b) => text_order(a.id, b.id))
  {
    profile: "cyclonedx-cargo-v1",
    raw: input,
    origin: nonempty(origin, "/origin"),
    packages,
    unresolved,
  }
}

///|
pub fn BomImport::source(self : BomImport) -> String {
  self.raw
}

///|
/// Export only when every component was resolved. Partial projections cannot be
/// mistaken for a complete inventory through this API.
pub fn BomImport::inventory_json(self : BomImport) -> Json raise InputError {
  if !self.unresolved.is_empty() {
    reject(
      "unresolved-components", "/components", "Resolve every component before exporting an inventory",
    )
  }
  inventory_json(self.packages)
}

///|
pub fn BomImport::to_json(self : BomImport) -> Json {
  {
    "profile": Json(self.profile),
    "origin": Json(self.origin),
    "source": Json(self.raw),
    "packages": Json(self.packages.map(p => p.to_json())),
    "unresolved": Json(
      self.unresolved.map(u => {
        "path": Json(u.path),
        "id": match u.id {
          None => Json::null()
          Some(id) => Json(id)
        },
        "code": Json(u.code),
      }),
    ),
  }
}

///|
pub fn BomImport::assess(
  self : BomImport,
  snapshot : Snapshot,
) -> BomAssessment raise InputError {
  let result = if self.packages.is_empty() {
    None
  } else {
    Some(assess(snapshot, self.packages))
  }
  { imported: self, result, snapshot, }
}

///|
pub fn BomAssessment::exit_code(self : BomAssessment) -> Int32 {
  if self.result is Some(result) && result.exit_code() == 1 {
    return 1
  }
  if !self.imported.unresolved.is_empty() {
    return 3
  }
  match self.result {
    None => 3
    Some(result) => result.exit_code()
  }
}

///|
pub fn BomAssessment::to_json(self : BomAssessment) -> Json {
  {
    "schema_version": 1,
    "scope": Json(
      "all listed components; Cargo PURL profile; no dependency reachability claim",
    ),
    "exit_code": Json(self.exit_code()),
    "import": self.imported.to_json(),
    "assessment": match self.result {
      None => Json::null()
      Some(result) => result.to_json()
    },
  }
}
