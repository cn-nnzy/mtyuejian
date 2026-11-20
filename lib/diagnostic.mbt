///|
/// A rejected input. Paths are JSON Pointers; messages never contain input values.
pub(all) suberror InputError {
  Invalid(code~ : String, path~ : String, message~ : String)
}

///|
pub fn InputError::to_json(self : InputError) -> Json {
  let Invalid(code~, path~, message~) = self
  { "code": Json(code), "path": Json(path), "message": Json(message) }
}

///|
fn reject(
  code : String,
  path : String,
  message : String,
) -> Unit raise InputError {
  raise Invalid(code~, path~, message~)
}

///|
fn pointer(path : String, key : String) -> String {
  let escaped = StringBuilder()
  let mut start = 0
  for i, unit in key.code_units() {
    if unit == 47 || unit == 126 {
      escaped.write_string(key[start:i].to_owned())
      escaped.write_string(if unit == 47 { "~1" } else { "~0" })
      start = i + 1
    }
  }
  escaped.write_string(key[start:].to_owned())
  path + "/" + escaped.to_string()
}
