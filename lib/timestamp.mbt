///|
fn date_number(value : String, start : Int32, length : Int32) -> Int32? {
  let mut n = 0
  for i in start..<(start + length) {
    let c = value.code_units()[i].to_int()
    if !digit(c) {
      return None
    }
    n = n * 10 + c - 48
  }
  Some(n)
}

///|
fn timestamp_valid(value : String) -> Bool {
  if value.length() < 20 || value.length() > 40 {
    return false
  }
  let u = value.code_units()
  if u[4] != 45 || u[7] != 45 || u[10] != 84 || u[13] != 58 || u[16] != 58 {
    return false
  }
  guard date_number(value, 0, 4) is Some(year) && year > 0 else { return false }
  guard date_number(value, 5, 2) is Some(month) && month >= 1 && month <= 12 else {
    return false
  }
  guard date_number(value, 8, 2) is Some(day) else { return false }
  let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
  let days = match month {
    2 => if leap { 29 } else { 28 }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
  if day < 1 || day > days {
    return false
  }
  guard date_number(value, 11, 2) is Some(hour) && hour < 24 else {
    return false
  }
  guard date_number(value, 14, 2) is Some(minute) && minute < 60 else {
    return false
  }
  guard date_number(value, 17, 2) is Some(second) && second < 60 else {
    return false
  }
  let mut pos = 19
  if u[pos] == 46 {
    pos += 1
    let start = pos
    while pos < u.length() && digit(u[pos].to_int()) {
      pos += 1
    }
    if pos == start || pos - start > 9 {
      return false
    }
  }
  if pos + 1 == u.length() && u[pos] == 90 {
    return true
  }
  if pos + 6 != u.length() || (u[pos] != 43 && u[pos] != 45) || u[pos + 3] != 58 {
    return false
  }
  guard date_number(value, pos + 1, 2) is Some(offset_hour) && offset_hour < 24 else {
    return false
  }
  guard date_number(value, pos + 4, 2) is Some(offset_minute) &&
    offset_minute < 60 else {
    return false
  }
  true
}

///|
fn timestamp_field(
  fields : Map[String, Value],
  key : String,
  path : String,
) -> String raise InputError {
  let value = string_field(fields, key, path)
  if !timestamp_valid(value) {
    reject(
      "invalid-timestamp",
      pointer(path, key),
      "Expected RFC 3339 with uppercase T/Z, up to 9 fractional digits and no leap seconds",
    )
  }
  value
}
