///|
#derive(Eq, Hash)
priv struct ScopeIdentity {
  ecosystem : String
  name : String
  version : String
}

///|
priv struct ScopeInstances {
  identity : ScopeIdentity
  left : Array[String]
  right : Array[String]
}

///|
/// Exact package identity counts from two independently imported inventories.
/// Producer IDs remain local to their respective inventory.
pub struct BomScopeComparison {
  priv left : BomImport
  priv right : BomImport
  priv groups : Array[ScopeInstances]
  priv shared : Int32
}

///|
fn index_scope(
  buckets : Map[ScopeIdentity, ScopeInstances],
  packages : ArrayView[Package],
  left : Bool,
) -> Unit {
  for item in packages {
    let identity = ScopeIdentity::{
      ecosystem: item.ecosystem,
      name: item.name,
      version: item.version,
    }
    let group = match buckets.get(identity) {
      Some(group) => group
      None => {
        let group = ScopeInstances::{ identity, left: [], right: [], }
        buckets[identity] = group
        group
      }
    }
    if left {
      group.left.push(item.id)
    } else {
      group.right.push(item.id)
    }
  }
}

///|
fn scope_identity_order(a : ScopeIdentity, b : ScopeIdentity) -> Int32 {
  let ecosystem = text_order(a.ecosystem, b.ecosystem)
  if ecosystem != 0 {
    return ecosystem
  }
  let name = text_order(a.name, b.name)
  if name != 0 {
    return name
  }
  text_order(a.version, b.version)
}

///|
/// Compare the exact (ecosystem, name, version) multiset. Each report group
/// contains source-local IDs. Duplicate IDs across sources are never paired.
/// Unresolved entries remain attached to their original source.
pub fn compare_bom_scope(
  left : BomImport,
  right : BomImport,
) -> BomScopeComparison {
  let buckets = Map([])
  // Importers already order packages by their source-local ID.
  index_scope(buckets, left.packages, true)
  index_scope(buckets, right.packages, false)
  let groups = []
  let mut shared = 0
  for _, group in buckets {
    shared += group.left.length().min(group.right.length())
    groups.push(group)
  }
  groups.sort_by((a, b) => scope_identity_order(a.identity, b.identity))
  { left, right, groups, shared, }
}

///|
/// 0 for identical resolved multiplicities and no unresolved entries.
/// 3 when counts differ or either inventory contains unresolved entries.
pub fn BomScopeComparison::exit_code(self : BomScopeComparison) -> Int32 {
  if self.shared == self.left.packages.length() &&
    self.shared == self.right.packages.length() &&
    self.left.unresolved.is_empty() &&
    self.right.unresolved.is_empty() {
    0
  } else {
    3
  }
}

///|
fn scope_source(input : BomImport) -> Json {
  let sha = @hex.encode(
    Bytes::from_array(@crypto.sha256(@utf8.encode(input.raw))[:])[:],
  )
  {
    "origin": Json(input.origin),
    "profile": Json(input.profile),
    "source_sha256": Json(sha),
    "resolved_instances": Json(input.packages.length()),
    "unresolved": Json(input.unresolved.map(row => unresolved_json(row))),
  }
}

///|
fn ScopeInstances::to_json(self : ScopeInstances) -> Json {
  let left = self.left.length()
  let right = self.right.length()
  let shared = left.min(right)
  {
    "ecosystem": Json(self.identity.ecosystem),
    "name": Json(self.identity.name),
    "version": Json(self.identity.version),
    "left_ids": Json(self.left.copy()),
    "right_ids": Json(self.right.copy()),
    "shared_instances": Json(shared),
    "left_only_instances": Json(left - shared),
    "right_only_instances": Json(right - shared),
    "repeated_identity": Json(left > 1 || right > 1),
  }
}

///|
/// Return a fresh view, including exact source hashes and unresolved pointers.
pub fn BomScopeComparison::to_json(self : BomScopeComparison) -> Json {
  {
    "schema_version": 1,
    "profile": "cargo-bom-scope-v1",
    "exit_code": Json(self.exit_code()),
    "left": scope_source(self.left),
    "right": scope_source(self.right),
    "counts": {
      "identities": Json(self.groups.length()),
      "shared_instances": Json(self.shared),
      "left_only_instances": Json(self.left.packages.length() - self.shared),
      "right_only_instances": Json(self.right.packages.length() - self.shared),
      "repeated_identities": Json(
        self.groups
        .filter(g => g.left.length() > 1 || g.right.length() > 1)
        .length(),
      ),
    },
    "identities": Json(self.groups.map(g => g.to_json())),
  }
}
