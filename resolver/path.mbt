///|
fn path_chars(path : String) -> Array[Char] {
  [
    for ch in path => if ch == '\\' { '/' } else { ch }
  ]
}

///|
fn is_absolute_or_special(path : String) -> Bool {
  let chars = path_chars(path)
  chars.get(0) == Some('/') ||
  chars.get(0) == Some('~') ||
  chars.any(ch => ch == ':')
}

///|
fn push_segment(segments : Array[String], segment : String) -> Bool {
  match segment {
    "" | "." => true
    ".." =>
      if segments.length() == 0 {
        false
      } else {
        ignore(segments.pop())
        true
      }
    value => {
      segments.push(value)
      true
    }
  }
}

///|
fn normalize_relative_path(base : String, path : String) -> String? {
  if path == "" || is_absolute_or_special(path) {
    return None
  }
  let combined = if base == "" { path } else { base + "/" + path }
  let segments : Array[String] = []
  let mut segment = StringBuilder()
  for ch in path_chars(combined) {
    if ch == '/' {
      if !push_segment(segments, segment.to_string()) {
        return None
      }
      segment = StringBuilder()
    } else {
      segment.write_char(ch)
    }
  }
  if !push_segment(segments, segment.to_string()) || segments.length() == 0 {
    None
  } else {
    Some(segments.join("/"))
  }
}

///|
fn parent_path(path : String) -> String {
  let chars = path_chars(path)
  let mut separator = -1
  for index, ch in chars {
    if ch == '/' {
      separator = index
    }
  }
  if separator < 0 {
    ""
  } else {
    let parent = StringBuilder()
    for index in 0..<separator {
      parent.write_char(chars[index])
    }
    parent.to_string()
  }
}
