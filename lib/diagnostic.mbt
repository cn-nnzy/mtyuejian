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
  path + "/" + key.replace(old="~", new="~0").replace(old="/", new="~1")
}
