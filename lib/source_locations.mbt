///|
priv struct SourceLocations {
  raw : String
  lines : Array[Int32]
  spans : Map[String, (Int32, Int32)]
  packages : Map[String, String]
}

///|
fn source_lines(raw : String) -> Array[Int32] {
  let units = raw.code_units()
  let lines = [0]
  let mut i = 0
  while i < units.length() {
    if units[i] == 13 {
      i += 1
      if i < units.length() && units[i] == 10 {
        i += 1
      }
      lines.push(i)
    } else if units[i] == 10 {
      i += 1
      lines.push(i)
    } else {
      i += 1
    }
  }
  lines
}

///|
fn source_position(lines : Array[Int32], offset : Int32) -> (Int32, Int32) {
  for lo = 0, hi = lines.length(); lo + 1 < hi; {
    let mid = lo + (hi - lo) / 2
    if lines[mid] <= offset {
      continue mid, hi
    } else {
      continue lo, mid
    }
  } nobreak {
    (lo + 1, offset - lines[lo] + 1)
  }
}

///|
fn inventory_locations(
  result : Assessment,
  raw : String,
) -> SourceLocations raise InputError {
  let packages = read_inventory(raw)
  let expected : Map[String, Package] = Map([])
  for row in result.decisions {
    expected[row.item.id] = row.item
  }
  if inventory_json(packages).stringify() !=
    inventory_json(expected.values().collect()).stringify() {
    reject(
      "source-inventory-mismatch", "/packages", "Location source must contain exactly the assessed installation IDs, identities and versions",
    )
  }
  let spans = Map([])
  read_value(raw, spans~) |> ignore
  let paths = Map([])
  for i, item in packages {
    paths[item.id] = "/packages/" + i.to_string() + "/version"
  }
  { raw, lines: source_lines(raw), spans, packages: paths, }
}

///|
fn cdx_location_paths(
  value : Value,
  path : String,
  paths : Map[String, String],
) -> Unit raise InputError {
  let fields = object(value, path)
  if optional_text(fields, "bom-ref", path) is Some(id) {
    paths[id] = path + "/version"
  }
  for i, child in optional_list(fields, "components", path, 1024) {
    cdx_location_paths(child, path + "/components/" + i.to_string(), paths)
  }
}

///|
fn bom_locations(imported : BomImport) -> SourceLocations raise InputError {
  let spans = Map([])
  let fields = object(read_value(imported.raw, spans~), "")
  let paths = Map([])
  if imported.profile == "spdx-cargo-v1" {
    for i, item in optional_list(fields, "packages", "", 1024) {
      let path = "/packages/" + i.to_string()
      if optional_text(object(item, path), "SPDXID", path) is Some(id) {
        paths[id] = path + "/versionInfo"
      }
    }
  } else {
    if fields.get("metadata") is Some(metadata) {
      let metadata = object(metadata, "/metadata")
      if metadata.get("component") is Some(subject) {
        cdx_location_paths(subject, "/metadata/component", paths)
      }
    }
    for i, item in optional_list(fields, "components", "", 1024) {
      cdx_location_paths(item, "/components/" + i.to_string(), paths)
    }
  }
  {
    raw: imported.raw,
    lines: source_lines(imported.raw),
    spans,
    packages: paths,
  }
}

///|
fn indexed_location(
  uri : String,
  source : SourceLocations?,
  path : String?,
) -> @sarif.SarifLocation {
  if source is Some(source) &&
    path is Some(path) &&
    source.spans.get(path) is Some((start, end)) {
    let (line, column) = source_position(source.lines, start)
    let (end_line, end_column) = source_position(source.lines, end)
    return @sarif.SarifLocation(
      @sarif.PhysicalLocation(
        @sarif.ArtifactLocation(uri, index=0),
        region=@sarif.Region(line, start_column=column, end_line~, end_column~),
      ),
    )
  }
  sarif_location(uri)
}

///|
fn package_location(
  uri : String,
  source : SourceLocations?,
  id : String,
) -> @sarif.SarifLocation {
  let path = match source {
    None => None
    Some(source) => source.packages.get(id)
  }
  indexed_location(uri, source, path)
}
