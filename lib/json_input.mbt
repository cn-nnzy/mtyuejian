///|
// Numbers stay as tokens. Unknown metadata must survive without Double rounding.
priv enum Value {
  Null
  True
  False
  Number(String)
  Text(String)
  List(Array[Value])
  Object(Map[String, Value])
}

///|
priv struct Reader {
  text : String
  units : ArrayView[UInt16]
  mut pos : Int32
  mut nodes : Int32
  spans : Map[String, (Int32, Int32)]?
  mut span_units : Int32
  mut path_units : Int32
}

///|
fn Reader::peek(self : Reader) -> Int32 {
  if self.pos < self.units.length() {
    self.units[self.pos].to_int()
  } else {
    -1
  }
}

///|
fn Reader::space(self : Reader) -> Unit {
  while [9, 10, 13, 32].contains(self.peek()) {
    self.pos += 1
  }
}

///|
fn Reader::expect(
  self : Reader,
  unit : Int32,
  path : String,
) -> Unit raise InputError {
  if self.peek() != unit {
    reject(
      "invalid-json",
      path,
      "Unexpected token at UTF-16 offset \{self.pos}",
    )
  }
  self.pos += 1
}

///|
fn digit(unit : Int32) -> Bool {
  unit >= 48 && unit <= 57
}

///|
fn Reader::child_path(
  self : Reader,
  parent : String,
  key : String,
) -> String raise InputError {
  let mut size = parent.length() + 1 + key.length()
  for unit in key.code_units() {
    if unit == 47 || unit == 126 {
      size += 1
    }
  }
  if size > 16777216 - self.path_units {
    reject(
      "json-work-limit", "", "JSON path construction exceeds 16777216 UTF-16 units; reduce deeply repeated metadata",
    )
  }
  self.path_units += size
  pointer(parent, key)
}

///|
fn Reader::string(self : Reader, path : String) -> String raise InputError {
  let start = self.pos
  self.expect(34, path)
  while self.peek() != 34 {
    if self.peek() < 32 {
      reject(
        "invalid-json-string", path, "Unterminated string or unescaped control character",
      )
    }
    if self.peek() == 92 {
      self.pos += 1
      if self.peek() < 0 {
        reject("invalid-json-string", path, "Incomplete escape")
      }
    }
    self.pos += 1
  }
  self.pos += 1
  let token = self.text[start:self.pos]
  let decoded = @json.parse(token, max_nesting_depth=1) catch {
    _ => {
      reject(
        "invalid-json-string", path, "Invalid escape or Unicode scalar sequence",
      )
      return ""
    }
  }
  guard decoded is String(value) else {
    reject("invalid-json-string", path, "Expected a string")
    return ""
  }
  value
}

///|
fn Reader::number(self : Reader, path : String) -> Value raise InputError {
  let start = self.pos
  if self.peek() == 45 {
    self.pos += 1
  }
  if self.peek() == 48 {
    self.pos += 1
  } else {
    if !digit(self.peek()) {
      reject("invalid-json-number", path, "Expected a decimal integer part")
    }
    while digit(self.peek()) {
      self.pos += 1
    }
  }
  if self.peek() == 46 {
    self.pos += 1
    if !digit(self.peek()) {
      reject("invalid-json-number", path, "Expected fraction digits")
    }
    while digit(self.peek()) {
      self.pos += 1
    }
  }
  if self.peek() == 69 || self.peek() == 101 {
    self.pos += 1
    if self.peek() == 43 || self.peek() == 45 {
      self.pos += 1
    }
    if !digit(self.peek()) {
      reject("invalid-json-number", path, "Expected exponent digits")
    }
    while digit(self.peek()) {
      self.pos += 1
    }
  }
  Number(self.text[start:self.pos].to_owned())
}

///|
fn Reader::literal(
  self : Reader,
  word : String,
  value : Value,
  path : String,
) -> Value raise InputError {
  for unit in word.code_units() {
    self.expect(unit.to_int(), path)
  }
  value
}

///|
fn Reader::value(
  self : Reader,
  depth : Int32,
  path : String,
) -> Value raise InputError {
  self.space()
  let start = self.pos
  self.nodes += 1
  if depth > 48 || self.nodes > 100000 {
    reject("json-limit", path, "JSON exceeds 48 levels or 100000 values")
  }
  let value = match self.peek() {
    34 => Text(self.string(path))
    110 => self.literal("null", Null, path)
    116 => self.literal("true", True, path)
    102 => self.literal("false", False, path)
    123 => {
      self.pos += 1
      self.space()
      let fields : Map[String, Value] = Map([])
      if self.peek() != 125 {
        while true {
          self.space()
          let key = self.string(path)
          let child = self.child_path(path, key)
          if fields.contains(key) {
            reject(
              "duplicate-key", child, "Object keys must be unique after escape decoding",
            )
          }
          self.space()
          self.expect(58, child)
          fields[key] = self.value(depth + 1, child)
          self.space()
          if self.peek() != 44 {
            break
          }
          self.pos += 1
        }
      }
      self.expect(125, path)
      Object(fields)
    }
    91 => {
      self.pos += 1
      self.space()
      let values = []
      if self.peek() != 93 {
        while true {
          values.push(
            self.value(
              depth + 1,
              self.child_path(path, values.length().to_string()),
            ),
          )
          self.space()
          if self.peek() != 44 {
            break
          }
          self.pos += 1
        }
      }
      self.expect(93, path)
      List(values)
    }
    45 | 48..<=57 => self.number(path)
    _ => {
      reject(
        "invalid-json",
        path,
        "Expected a JSON value at UTF-16 offset \{self.pos}",
      )
      Null
    }
  }
  if self.spans is Some(spans) {
    self.span_units += path.length()
    if self.span_units > 4194304 {
      reject(
        "source-index-limit", "", "Source index exceeds 4194304 UTF-16 units of JSON Pointer text; use artifact-only export",
      )
    }
    spans[path] = (start, self.pos)
  }
  value
}

///|
fn read_value(
  text : String,
  max_units~ : Int32 = 1048576,
  spans? : Map[String, (Int32, Int32)],
) -> Value raise InputError {
  if text.length() > max_units {
    reject("document-limit", "", "Document exceeds its UTF-16 code unit budget")
  }
  // Library callers can construct Strings independently of a strict UTF-8 host.
  let units = text.code_units()
  let mut i = 0
  while i < units.length() {
    let c = units[i].to_int()
    if c >= 0xD800 && c <= 0xDBFF {
      if i + 1 >= units.length() ||
        units[i + 1] < 0xDC00 ||
        units[i + 1] > 0xDFFF {
        reject("invalid-unicode", "", "Unpaired UTF-16 surrogate")
      }
      i += 2
    } else {
      if c >= 0xDC00 && c <= 0xDFFF {
        reject("invalid-unicode", "", "Unpaired UTF-16 surrogate")
      }
      i += 1
    }
  }
  let reader = Reader::{
    text,
    units,
    pos: 0,
    nodes: 0,
    spans,
    span_units: 0,
    path_units: 0,
  }
  let value = reader.value(0, "")
  reader.space()
  if reader.pos != text.length() {
    reject("trailing-json", "", "Unexpected content after the document")
  }
  value
}

///|
fn object(value : Value, path : String) -> Map[String, Value] raise InputError {
  guard value is Object(fields) else {
    reject("expected-object", path, "Expected an object; found " + value.kind())
    return Map([])
  }
  fields
}

///|
fn Value::kind(self : Value) -> String {
  match self {
    Null => "null"
    True | False => "boolean"
    Number(_) => "number"
    Text(_) => "string"
    List(_) => "array"
    Object(_) => "object"
  }
}

///|
fn text(value : Value, path : String) -> String raise InputError {
  guard value is Text(value) else {
    reject("expected-string", path, "Expected a string")
    return ""
  }
  value
}

///|
fn required(
  fields : Map[String, Value],
  key : String,
  path : String,
) -> Value raise InputError {
  guard fields.get(key) is Some(value) else {
    reject("missing-field", pointer(path, key), "Required field is missing")
    return Null
  }
  value
}

///|
fn nonempty(value : String, path : String) -> String raise InputError {
  if value.trim().is_empty() || value.length() > 4096 {
    reject(
      "invalid-text", path, "Expected nonblank text of at most 4096 UTF-16 code units",
    )
  }
  value
}

///|
fn string_field(
  fields : Map[String, Value],
  key : String,
  path : String,
) -> String raise InputError {
  nonempty(
    text(required(fields, key, path), pointer(path, key)),
    pointer(path, key),
  )
}

///|
fn list(
  value : Value,
  path : String,
  max : Int32,
) -> Array[Value] raise InputError {
  guard value is List(values) else {
    reject("expected-array", path, "Expected an array")
    return []
  }
  if values.length() > max {
    reject("array-limit", path, "Array exceeds its item budget")
  }
  values
}

///|
fn optional_list(
  fields : Map[String, Value],
  key : String,
  path : String,
  max : Int32,
) -> Array[Value] raise InputError {
  match fields.get(key) {
    None => []
    Some(value) => list(value, pointer(path, key), max)
  }
}

///|
fn known_fields(
  fields : Map[String, Value],
  names : Array[String],
  path : String,
) -> Unit raise InputError {
  for key, _ in fields {
    if !names.contains(key) {
      reject(
        "unsupported-field",
        pointer(path, key),
        "Field is outside this version's supported profile",
      )
    }
  }
}
