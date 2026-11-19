///|
priv struct Version {
  core : Array[String]
  pre : Array[String]
}

///|
fn decimal(value : String) -> Bool {
  !value.is_empty() && value.code_units().all(c => c >= 48 && c <= 57)
}

///|
fn identifiers(value : String, prerelease : Bool) -> Array[String]? {
  let parts = value.split(".").map(p => p.to_owned()).collect()
  for part in parts {
    if part.is_empty() ||
      !part
      .code_units()
      .all(c => {
        (c >= 48 && c <= 57) ||
        (c >= 65 && c <= 90) ||
        (c >= 97 && c <= 122) ||
        c == 45
      }) {
      return None
    }
    if prerelease && decimal(part) && part.length() > 1 && part.has_prefix("0") {
      return None
    }
  }
  Some(parts)
}

///|
fn parse_version(value : String) -> Version? {
  if value.is_empty() || value.length() > 256 {
    return None
  }
  let main = match value.split_once("+") {
    None => value
    Some((main, build)) => {
      guard identifiers(build.to_owned(), false) is Some(_) else { return None }
      main.to_owned()
    }
  }
  let (core_text, pre) = match main.split_once("-") {
    None => (main, [])
    Some((core, pre)) => {
      guard identifiers(pre.to_owned(), true) is Some(parts) else {
        return None
      }
      (core.to_owned(), parts)
    }
  }
  let core = core_text.split(".").map(p => p.to_owned()).collect()
  if core.length() != 3 {
    return None
  }
  for part in core {
    if !decimal(part) || (part.length() > 1 && part.has_prefix("0")) {
      return None
    }
  }
  Some({ core, pre, })
}

///|
fn numeric_compare(a : String, b : String) -> Int32 {
  if a.length() != b.length() {
    a.length().compare(b.length())
  } else {
    text_order(a, b)
  }
}

///|
// SemVer requires ASCII lexical ordering, independent of host String ordering.
fn text_order(a : String, b : String) -> Int32 {
  let au = a.code_units()
  let bu = b.code_units()
  for i in 0..<au.length().min(bu.length()) {
    if au[i] != bu[i] {
      return au[i].compare(bu[i])
    }
  }
  au.length().compare(bu.length())
}

///|
fn Version::compare(self : Version, other : Version) -> Int32 {
  for i in 0..<3 {
    let order = numeric_compare(self.core[i], other.core[i])
    if order != 0 {
      return order
    }
  }
  if self.pre.is_empty() && other.pre.is_empty() {
    return 0
  }
  if self.pre.is_empty() {
    return 1
  }
  if other.pre.is_empty() {
    return -1
  }
  for i in 0..<self.pre.length().min(other.pre.length()) {
    let a = self.pre[i]
    let b = other.pre[i]
    let order = match (decimal(a), decimal(b)) {
      (true, true) => numeric_compare(a, b)
      (true, false) => -1
      (false, true) => 1
      (false, false) => text_order(a, b)
    }
    if order != 0 {
      return order
    }
  }
  self.pre.length().compare(other.pre.length())
}

///|
fn version_at(value : String, path : String) -> Version raise InputError {
  guard parse_version(value) is Some(version) else {
    reject(
      "invalid-semver", path, "Expected strict SemVer 2.0.0 of at most 256 code units",
    )
    return { core: [], pre: [], }
  }
  version
}
