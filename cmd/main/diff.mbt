///|
priv struct DiffArtifact {
  path : String
  fingerprint : String
  issues : Array[String]
}

///|
priv struct AuditSnapshot {
  artifacts : Array[DiffArtifact]
  errors : Array[String]
}

///|
priv struct ChangedArtifact {
  path : String
  before_fingerprint : String
  after_fingerprint : String
  added_issues : Array[String]
  removed_issues : Array[String]
}

///|
priv struct AuditDiff {
  added : Array[String]
  removed : Array[String]
  changed : Array[ChangedArtifact]
  unchanged : Array[String]
  errors_added : Array[String]
  errors_removed : Array[String]
}

///|
fn diff_string_field(
  fields : Map[String, Json],
  name : String,
) -> Result[String, String] {
  match fields.get(name) {
    Some(value) =>
      Ok(@json.from_json(value)) catch {
        _ => Err("field \{name} must be a string")
      }
    None => Err("missing required field \{name}")
  }
}

///|
fn diff_issue_codes(value : Json) -> Result[Array[String], String] {
  guard value is Array(items) else {
    return Err("field issues must be an array")
  }
  let codes : Array[String] = []
  for item in items {
    guard item is Object(fields) else {
      return Err("each issue must be a JSON object")
    }
    let code = match diff_string_field(fields, "code") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    codes.push(code)
  }
  Ok(codes)
}

///|
fn diff_artifact(value : Json) -> Result[DiffArtifact, String] {
  guard value is Object(fields) else {
    return Err("each artifact must be a JSON object")
  }
  let path = match diff_string_field(fields, "path") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let fingerprint = match diff_string_field(fields, "fingerprint") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let issues = match fields.get("issues") {
    Some(value) =>
      match diff_issue_codes(value) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
    None => []
  }
  Ok({ path, fingerprint, issues, })
}

///|
fn diff_error_paths(value : Json) -> Result[Array[String], String] {
  guard value is Array(items) else {
    return Err("field errors must be an array")
  }
  let paths : Array[String] = []
  for item in items {
    guard item is Object(fields) else {
      return Err("each error must be a JSON object")
    }
    let path = match diff_string_field(fields, "path") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    paths.push(path)
  }
  Ok(paths)
}

///|
fn parse_audit_snapshot(text : String) -> Result[AuditSnapshot, String] {
  let parsed = @json.parse(text) catch {
    error => return Err("invalid JSON: \{error}")
  }
  guard parsed is Object(fields) else {
    return Err("audit report must be a JSON object")
  }
  let artifacts : Array[DiffArtifact] = []
  let errors : Array[String] = []
  match fields.get("artifacts") {
    None =>
      match diff_artifact(parsed) {
        Ok(artifact) => artifacts.push(artifact)
        Err(message) => return Err(message)
      }
    Some(value) => {
      guard value is Array(items) else {
        return Err("field artifacts must be an array")
      }
      for item in items {
        let artifact = match diff_artifact(item) {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        if artifacts.any(existing => existing.path == artifact.path) {
          return Err("duplicate artifact path \{artifact.path}")
        }
        artifacts.push(artifact)
      }
      match fields.get("errors") {
        None => ()
        Some(value) =>
          match diff_error_paths(value) {
            Ok(value) => append_all(errors, value)
            Err(message) => return Err(message)
          }
      }
    }
  }
  Ok({ artifacts, errors, })
}

///|
fn diff_contains(values : Array[String], value : String) -> Bool {
  values.any(item => item == value)
}

///|
fn diff_equal_strings(left : Array[String], right : Array[String]) -> Bool {
  left.length() == right.length() &&
  left.all(item => diff_contains(right, item))
}

///|
fn diff_difference(
  left : Array[String],
  right : Array[String],
) -> Array[String] {
  [
    for value in left if !diff_contains(right, value) => value
  ]
}

///|
fn diff_find_artifact(
  artifacts : Array[DiffArtifact],
  path : String,
) -> DiffArtifact? {
  for artifact in artifacts {
    if artifact.path == path {
      return Some(artifact)
    }
  }
  None
}

///|
fn compare_audit_snapshots(
  before : AuditSnapshot,
  after : AuditSnapshot,
) -> AuditDiff {
  let added : Array[String] = []
  let removed : Array[String] = []
  let changed : Array[ChangedArtifact] = []
  let unchanged : Array[String] = []
  for artifact in after.artifacts {
    match diff_find_artifact(before.artifacts, artifact.path) {
      None => added.push(artifact.path)
      Some(previous) =>
        if previous.fingerprint == artifact.fingerprint &&
          diff_equal_strings(previous.issues, artifact.issues) {
          unchanged.push(artifact.path)
        } else {
          changed.push({
            path: artifact.path,
            before_fingerprint: previous.fingerprint,
            after_fingerprint: artifact.fingerprint,
            added_issues: diff_difference(artifact.issues, previous.issues),
            removed_issues: diff_difference(previous.issues, artifact.issues),
          })
        }
    }
  }
  for artifact in before.artifacts {
    if diff_find_artifact(after.artifacts, artifact.path) is None {
      removed.push(artifact.path)
    }
  }
  {
    added,
    removed,
    changed,
    unchanged,
    errors_added: diff_difference(after.errors, before.errors),
    errors_removed: diff_difference(before.errors, after.errors),
  }
}

///|
fn audit_diff_has_changes(diff : AuditDiff) -> Bool {
  diff.added.length() > 0 ||
  diff.removed.length() > 0 ||
  diff.changed.length() > 0 ||
  diff.errors_added.length() > 0 ||
  diff.errors_removed.length() > 0
}

///|
fn diff_write_strings(output : StringBuilder, values : Array[String]) -> Unit {
  output.write_char('[')
  for index, value in values {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(json_quote(value))
  }
  output.write_char(']')
}

///|
fn diff_json(diff : AuditDiff) -> String {
  let output = StringBuilder()
  output.write_string("{\"added\":")
  diff_write_strings(output, diff.added)
  output.write_string(",\"removed\":")
  diff_write_strings(output, diff.removed)
  output.write_string(",\"changed\":[")
  for index, item in diff.changed {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string("{\"path\":")
    output.write_string(json_quote(item.path))
    output.write_string(",\"before_fingerprint\":")
    output.write_string(json_quote(item.before_fingerprint))
    output.write_string(",\"after_fingerprint\":")
    output.write_string(json_quote(item.after_fingerprint))
    output.write_string(",\"added_issues\":")
    diff_write_strings(output, item.added_issues)
    output.write_string(",\"removed_issues\":")
    diff_write_strings(output, item.removed_issues)
    output.write_char('}')
  }
  output.write_string("],\"unchanged\":")
  diff_write_strings(output, diff.unchanged)
  output.write_string(",\"errors_added\":")
  diff_write_strings(output, diff.errors_added)
  output.write_string(",\"errors_removed\":")
  diff_write_strings(output, diff.errors_removed)
  output.write_string(",\"summary\":{\"added\":")
  output.write_string(diff.added.length().to_string())
  output.write_string(",\"removed\":")
  output.write_string(diff.removed.length().to_string())
  output.write_string(",\"changed\":")
  output.write_string(diff.changed.length().to_string())
  output.write_string(",\"unchanged\":")
  output.write_string(diff.unchanged.length().to_string())
  output.write_string(",\"errors_added\":")
  output.write_string(diff.errors_added.length().to_string())
  output.write_string(",\"errors_removed\":")
  output.write_string(diff.errors_removed.length().to_string())
  output.write_string("},\"status\":")
  output.write_string(
    json_quote(
      if audit_diff_has_changes(diff) {
        "changed"
      } else {
        "unchanged"
      },
    ),
  )
  output.write_string("}\n")
  output.to_string()
}

///|
fn diff_write_named_paths(
  output : StringBuilder,
  title : String,
  values : Array[String],
  marker : String,
) -> Unit {
  if values.length() > 0 {
    output.write_string("\{title} (\{values.length()})\n")
    for value in values {
      output.write_string("  \{marker} \{value}\n")
    }
  }
}

///|
fn diff_text(
  before_path : String,
  after_path : String,
  diff : AuditDiff,
) -> String {
  let output = StringBuilder()
  output.write_string("diff: \{before_path} -> \{after_path}\n")
  diff_write_named_paths(output, "added", diff.added, "+")
  diff_write_named_paths(output, "removed", diff.removed, "-")
  if diff.changed.length() > 0 {
    output.write_string("changed (\{diff.changed.length()})\n")
    for item in diff.changed {
      output.write_string("  ~ \{item.path}\n")
      if item.before_fingerprint != item.after_fingerprint {
        output.write_string(
          "    fingerprint: \{item.before_fingerprint} -> \{item.after_fingerprint}\n",
        )
      }
      if item.added_issues.length() > 0 {
        output.write_string(
          "    issues added: \{item.added_issues.join(", ")}\n",
        )
      }
      if item.removed_issues.length() > 0 {
        output.write_string(
          "    issues removed: \{item.removed_issues.join(", ")}\n",
        )
      }
    }
  }
  diff_write_named_paths(output, "unchanged", diff.unchanged, "=")
  diff_write_named_paths(output, "errors added", diff.errors_added, "+")
  diff_write_named_paths(output, "errors removed", diff.errors_removed, "-")
  output.write_string(
    "summary: added=\{diff.added.length()} removed=\{diff.removed.length()} changed=\{diff.changed.length()} unchanged=\{diff.unchanged.length()} errors_added=\{diff.errors_added.length()} errors_removed=\{diff.errors_removed.length()}\n",
  )
  output.write_string(
    "status: \{if audit_diff_has_changes(diff) { "changed" } else { "unchanged" }}\n",
  )
  output.to_string()
}
