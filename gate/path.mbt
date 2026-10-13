///|
/// Paths in a bundle are canonical repository-relative names, never OS paths.
fn valid_relative_path(path : String) -> Bool {
  if path == "" || path.has_prefix("/") || path.has_suffix("/") {
    return false
  }
  let mut segment = StringBuilder()
  for ch in path {
    if ch == '/' {
      let part = segment.to_string()
      if part == "" ||
        part == "." ||
        part == ".." ||
        part.has_suffix(".") ||
        part.has_suffix(" ") {
        return false
      }
      segment = StringBuilder()
    } else if ch == '\\' || ch == ':' || ch < ' ' || ch == '\u{007f}' {
      return false
    } else {
      segment.write_char(ch)
    }
  }
  let last = segment.to_string()
  last != "" &&
  last != "." &&
  last != ".." &&
  !last.has_suffix(".") &&
  !last.has_suffix(" ")
}

///|

///|
/// Check a repository-relative source path before filesystem or Git access.
pub fn source_path_is_allowed(root : String, path : String) -> Bool {
  valid_relative_path(root) &&
  valid_relative_path(path) &&
  path.has_prefix(root + "/")
}

///|
fn valid_evidence_id(id : String) -> Bool {
  if id == "" {
    return false
  }
  for ch in id {
    if !((ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '-' ||
      ch == '_') {
      return false
    }
  }
  true
}
