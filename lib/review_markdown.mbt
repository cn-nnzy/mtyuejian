///|
priv struct ReviewWriter {
  output : StringBuilder
  mut units : Int32
}

///|
fn ReviewWriter::write(
  self : ReviewWriter,
  text : String,
) -> Unit raise InputError {
  if text.length() > 8388608 - self.units {
    reject(
      "review-size-limit", "", "Markdown review exceeds 8388608 UTF-16 units; no partial report is returned",
    )
  }
  self.units += text.length()
  self.output.write_string(text)
}

///|
fn backtick_run(text : String) -> Int32 {
  let mut longest = 0
  let mut current = 0
  for unit in text.code_units() {
    if unit == 96 {
      current += 1
      longest = longest.max(current)
    } else {
      current = 0
    }
  }
  longest
}

///|
fn review_inline(value : Json) -> String {
  // JSON quoting makes JSON control characters visible; a longer delimiter prevents
  // source values from closing code spans or introducing links/HTML formatting.
  let text = value.stringify()
  let fence = "`".repeat(backtick_run(text) + 1)
  fence + text + fence
}

///|
fn review_aliases(writer : ReviewWriter, view : Json) -> Unit raise InputError {
  guard view
    is {
      "groups": Array(groups),
      "unassigned_decision_indices": unassigned,
      ..
    } else {
    reject(
      "review-layout", "", "Internal alias review is missing required fields",
    )
    return
  }
  writer.write(
    "\n## Advisory source groups\n\nGroups follow declared identifiers; source decisions are retained separately.\n\n",
  )
  for i, group in groups {
    guard group
      is {
        "records": Array(records),
        "identifiers": identifiers,
        "links": Array(links),
        "decision_indices": indices,
        "unscoped_entries": Array(unscoped),
        "has_scoped_decisions": scoped,
        "has_known_match": matched,
        "has_incomplete_evidence": incomplete,
        ..
      } else {
      reject("review-layout", "", "Internal source group is incomplete")
      return
    }
    writer.write(
      "### Source group " +
      (i + 1).to_string() +
      "\n\nIdentifiers: " +
      review_inline(identifiers) +
      "\n\n",
    )
    for record in records {
      guard record
        is {
          "snapshot_index": index,
          "id": id,
          "origin": origin,
          "modified": modified,
          "withdrawn": withdrawn,
          ..
        } else {
        reject("review-layout", "", "Internal source record is incomplete")
        return
      }
      writer.write(
        "- Record " +
        review_inline(index) +
        ": " +
        review_inline(id) +
        "; origin " +
        review_inline(origin) +
        "; modified " +
        review_inline(modified) +
        "; withdrawn " +
        review_inline(withdrawn) +
        ".\n",
      )
    }
    for link in links {
      guard link
        is { "identifier": identifier, "record_indices": record_indices, .. } else {
        reject("review-layout", "", "Internal source link is incomplete")
        return
      }
      writer.write(
        "- Shared identifier " +
        review_inline(identifier) +
        " links snapshot record indices " +
        review_inline(record_indices) +
        ".\n",
      )
    }
    writer.write(
      "\nDecision indices: " +
      review_inline(indices) +
      ". Scoped decisions: " +
      review_inline(scoped) +
      "; known match: " +
      review_inline(matched) +
      "; incomplete evidence: " +
      review_inline(incomplete) +
      ".\n\n",
    )
    for entry in unscoped {
      writer.write(
        "- Active entry without package identity: " +
        review_inline(entry) +
        ".\n",
      )
    }
  }
  writer.write(
    "\nUnassigned decision indices (including packages without advisories): " +
    review_inline(unassigned) +
    ".\n",
  )
}

///|
fn render_receipt_review(
  receipt : Json,
  digest : String,
  decisions : Array[Decision],
  code : Int32,
  aliases : Json,
  unresolved : Array[UnresolvedComponent],
  coverage : Json,
) -> String raise InputError {
  let writer : ReviewWriter = { output: StringBuilder(), units: 0, }
  writer.write(
    "# Yuejian assessment review\n\nAssessment exit code: " +
    code.to_string() +
    "\n\nReceipt SHA-256: " +
    review_inline(Json(digest)) +
    "\n\nThis is supplied version evidence, not an exploitability or whole-database safety verdict.\n\n## Source decisions\n\nDecision rows are counted per installed package and source record, not per unique CVE.\n\n",
  )
  for outcome in [Affected, NotMatched, Undetermined, Withdrawn, NoAdvisory] {
    writer.write(
      "- " +
      outcome.label() +
      ": " +
      decisions.filter(d => d.outcome == outcome).length().to_string() +
      "\n",
    )
  }
  writer.write("\n")
  for i, decision in decisions {
    let item = decision.item
    writer.write(
      "- Decision " +
      i.to_string() +
      ": installation " +
      review_inline(Json(item.id)) +
      "; package " +
      review_inline(Json(item.ecosystem + "/" + item.name + "@" + item.version)) +
      "; advisory " +
      review_inline(
        match decision.advisory {
          None => Json::null()
          Some(id) => Json(id)
        },
      ) +
      "; **" +
      decision.outcome.label() +
      "**; incomplete " +
      review_inline(Json(decision.incomplete)) +
      ".\n",
    )
    for evidence in decision.evidence {
      writer.write(
        "  - Evidence " +
        review_inline(Json(evidence.code)) +
        " at " +
        review_inline(Json(evidence.path)) +
        "; original event indices " +
        review_inline(Json(evidence.indices)) +
        ".\n",
      )
    }
  }
  writer.write(
    "\n## Unresolved BOM evidence\n\nUnresolved entries: " +
    unresolved.length().to_string() +
    "\n\n",
  )
  for row in unresolved {
    writer.write(
      "- " +
      review_inline(Json(row.code)) +
      " at " +
      review_inline(Json(row.path)) +
      "; identifier " +
      review_inline(
        match row.id {
          None => Json::null()
          Some(id) => Json(id)
        },
      ) +
      ".\n",
    )
  }
  guard coverage
    is {
      "counts": counts,
      "diagnostic_counts": categories,
      "diagnostics": Array(diagnostics),
      ..
    } else {
    reject("review-layout", "", "Coverage view is incomplete")
    return ""
  }
  writer.write(
    "\n## Coverage and next steps\n\nPackage counts (not a safety score): " +
    review_inline(counts) +
    ".\n\nDiagnostic counts: " +
    review_inline(categories) +
    ".\n\n",
  )
  for diagnostic in diagnostics {
    writer.write("- " + review_inline(diagnostic) + "\n")
  }
  review_aliases(writer, aliases)
  let payload = receipt.stringify()
  let fence = "`".repeat((backtick_run(payload) + 1).max(3))
  writer.write(
    "\n## Complete receipt\n\nCopy the JSON block for verified replay. It retains all original source and unsupported metadata.\n\n" +
    fence +
    "json\n",
  )
  writer.write(payload)
  writer.write("\n" + fence + "\n")
  writer.output.to_string()
}

///|
/// Render a literal-text review plus a complete, replayable JSON receipt. Source
/// values use adaptive code delimiters; generation refuses oversized output.
pub fn Delivery::to_markdown(self : Delivery) -> String raise InputError {
  render_receipt_review(
    self.to_json(),
    self.digest,
    self.assessment.decisions,
    self.assessment.exit_code(),
    self.alias_review(),
    [],
    self.assessment.coverage(),
  )
}

///|
/// Include unresolved BOM entries and the outer assessment gate, even when there
/// are no resolved packages. The canonical receipt preserves exact source payloads.
pub fn BomDelivery::to_markdown(self : BomDelivery) -> String raise InputError {
  let decisions = match self.result.result {
    None => []
    Some(result) => result.decisions
  }
  render_receipt_review(
    self.to_json(),
    self.digest,
    decisions,
    self.result.exit_code(),
    self.alias_review(),
    self.result.imported.unresolved,
    self.result.coverage(),
  )
}
