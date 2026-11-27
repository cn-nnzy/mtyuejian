///|
/// One caller-identified installed package. Names and ecosystems match exactly.
pub struct Package {
  priv id : String
  priv ecosystem : String
  priv name : String
  priv version : String
}

///|
/// Versions may use an ecosystem-specific spelling; unsupported ordering is
/// reported as Undetermined rather than coerced to SemVer.
pub fn Package::new(
  id~ : String,
  ecosystem~ : String,
  name~ : String,
  version~ : String,
) -> Package raise InputError {
  {
    id: nonempty(id, "/id"),
    ecosystem: nonempty(ecosystem, "/ecosystem"),
    name: nonempty(name, "/name"),
    version: nonempty(version, "/version"),
  }
}

///|
pub fn Package::to_json(self : Package) -> Json {
  {
    "id": Json(self.id),
    "ecosystem": Json(self.ecosystem),
    "name": Json(self.name),
    "version": Json(self.version),
  }
}

///|
fn profile(
  fields : Map[String, Value],
  names : Array[String],
) -> Unit raise InputError {
  known_fields(fields, names, "")
  guard required(fields, "schema_version", "") is Number("1") else {
    reject(
      "unsupported-profile", "/schema_version", "Expected the integer token 1",
    )
  }
}

///|
/// Read the closed inventory-v1 format. Unknown fields and duplicate package IDs
/// are errors, so a misspelled selector cannot silently disappear.
pub fn read_inventory(input : String) -> Array[Package] raise InputError {
  let fields = object(read_value(input), "")
  profile(fields, ["schema_version", "packages"])
  let values = list(required(fields, "packages", ""), "/packages", 1024)
  if values.is_empty() {
    reject("empty-inventory", "/packages", "Provide at least one package")
  }
  let packages = []
  let ids : Map[String, Unit] = Map([])
  for i, value in values {
    let path = "/packages/" + i.to_string()
    let fields = object(value, path)
    known_fields(fields, ["id", "ecosystem", "name", "version"], path)
    let item = Package::new(
      id=string_field(fields, "id", path),
      ecosystem=string_field(fields, "ecosystem", path),
      name=string_field(fields, "name", path),
      version=string_field(fields, "version", path),
    )
    if ids.contains(item.id) {
      reject(
        "duplicate-package-id",
        pointer(path, "id"),
        "Package IDs must be unique",
      )
    }
    ids[item.id] = ()
    packages.push(item)
  }
  packages
}

///|
/// Deterministic inventory-v1 serialization; rejects duplicate IDs and encoded
/// documents exceeding the paired reader's 1048576 UTF-16 unit budget.
pub fn inventory_json(packages : ArrayView[Package]) -> Json raise InputError {
  if packages.is_empty() || packages.length() > 1024 {
    reject("inventory-limit", "/packages", "Expected 1 to 1024 packages")
  }
  let sorted = packages.to_owned()
  sorted.sort_by((a, b) => text_order(a.id, b.id))
  for i in 1..<sorted.length() {
    if sorted[i - 1].id == sorted[i].id {
      reject("duplicate-package-id", "/packages", "Package IDs must be unique")
    }
  }
  let view : Json = {
    "schema_version": 1,
    "packages": Json(sorted.map(p => p.to_json())),
  }
  if view.stringify().length() > 1048576 {
    reject(
      "document-limit", "/packages", "Encoded inventory exceeds 1048576 UTF-16 code units; split the inventory into bounded assessments",
    )
  }
  view
}
