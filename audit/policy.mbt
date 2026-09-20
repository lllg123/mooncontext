///|
/// A versioned, reusable audit policy loaded from JSON.
///
/// `policy` contains the content rules, while `deny_warnings` controls whether
/// warnings fail the audit gate.
pub(all) struct PolicyConfig {
  version : Int
  policy : Policy
  deny_warnings : Bool
} derive(Debug, Eq)

///|
fn decode_int_field(
  fields : Map[String, Json],
  name : String,
) -> Result[Int, String] {
  match fields.get(name) {
    None => Err("missing required field `\{name}`")
    Some(value) => {
      guard value is Number(number, ..) else {
        return Err("field `\{name}` must be an integer")
      }
      try {
        let decoded : Int = @json.from_json(value)
        if number == decoded.to_double() {
          Ok(decoded)
        } else {
          Err("field `\{name}` must be an integer")
        }
      } catch {
        _ => Err("field `\{name}` must be an integer")
      }
    }
  }
}

///|
fn decode_string_array_field(
  fields : Map[String, Json],
  name : String,
) -> Result[Array[String], String] {
  match fields.get(name) {
    None => Ok([])
    Some(value) =>
      try {
        let decoded : Array[String] = @json.from_json(value)
        Ok(decoded)
      } catch {
        _ => Err("field `\{name}` must be an array of strings")
      }
  }
}

///|
fn decode_bool_field(
  fields : Map[String, Json],
  name : String,
) -> Result[Bool, String] {
  match fields.get(name) {
    None => Ok(false)
    Some(value) =>
      try {
        let decoded : Bool = @json.from_json(value)
        Ok(decoded)
      } catch {
        _ => Err("field `\{name}` must be a boolean")
      }
  }
}

///|
fn validate_markers(
  markers : Array[String],
  name : String,
) -> Result[Unit, String] {
  for marker in markers {
    if marker == "" {
      return Err("field `\{name}` must not contain an empty marker")
    }
  }
  Ok(())
}

///|
/// Parse a reusable audit policy from a versioned JSON document.
///
/// Unknown fields are rejected so misspelled safety rules cannot silently be
/// ignored. Marker arrays and `deny_warnings` are optional and default to an
/// empty array and `false` respectively.
///
/// ```mbt check
/// test {
///   let policy = @audit.parse_policy_json(
///     "{\"version\":1,\"char_budget\":1200,\"required_markers\":[\"Role\"]}",
///   )
///   guard policy is Ok(config) else { fail("expected a valid policy") }
///   assert_eq(config.policy.char_budget, 1200)
/// }
/// ```
pub fn parse_policy_json(text : String) -> Result[PolicyConfig, String] {
  let parsed = @json.parse(text) catch {
    error => return Err("invalid JSON: \{error}")
  }
  guard parsed is Object(fields) else {
    return Err("policy document must be a JSON object")
  }
  for name, _ in fields {
    if name != "version" &&
      name != "char_budget" &&
      name != "required_markers" &&
      name != "forbidden_markers" &&
      name != "deny_warnings" {
      return Err("unknown policy field `\{name}`")
    }
  }
  let version = match decode_int_field(fields, "version") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if version != 1 {
    return Err("unsupported policy version `\{version}`; expected 1")
  }
  let char_budget = match decode_int_field(fields, "char_budget") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if char_budget <= 0 {
    return Err("field `char_budget` must be greater than zero")
  }
  let required_markers = match
    decode_string_array_field(fields, "required_markers") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match validate_markers(required_markers, "required_markers") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let forbidden_markers = match
    decode_string_array_field(fields, "forbidden_markers") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match validate_markers(forbidden_markers, "forbidden_markers") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let deny_warnings = match decode_bool_field(fields, "deny_warnings") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({
    version,
    policy: Policy::with_forbidden(
      char_budget~,
      required_markers~,
      forbidden_markers~,
    ),
    deny_warnings,
  })
}
