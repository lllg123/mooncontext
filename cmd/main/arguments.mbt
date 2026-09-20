///|
priv struct CommandOptions {
  action : String
  input : String
  output : String?
  source_map : String?
  manifest : String?
  definitions : Array[@semantics.Definition]
  policy_path : String?
  audit_budget : Int?
  required_markers : Array[String]
  forbidden_markers : Array[String]
  report : String?
  json : Bool
  deny_warnings : Bool
}

///|
priv struct ArgumentResult {
  options : CommandOptions?
  help : Bool
  error : String?
}

///|
fn valid_identifier(value : String) -> Bool {
  let chars = [ for ch in value => ch ]
  match chars.get(0) {
    Some(ch) if (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      ch == '_' => {
      let mut valid = true
      for index in 1..<chars.length() {
        let current = chars[index]
        if !((current >= 'a' && current <= 'z') ||
          (current >= 'A' && current <= 'Z') ||
          (current >= '0' && current <= '9') ||
          current == '_') {
          valid = false
        }
      }
      valid
    }
    _ => false
  }
}

///|
fn parse_definition(value : String) -> @semantics.Definition? {
  let name = StringBuilder()
  let definition_value = StringBuilder()
  let mut separator_seen = false
  for ch in value {
    if !separator_seen && ch == '=' {
      separator_seen = true
    } else if separator_seen {
      definition_value.write_char(ch)
    } else {
      name.write_char(ch)
    }
  }
  let name = name.to_string()
  if separator_seen && valid_identifier(name) {
    Some({ name, value: definition_value.to_string(), })
  } else {
    None
  }
}

///|
fn parse_positive_integer(value : String) -> Int? {
  let chars = [ for ch in value => ch ]
  if chars.length() == 0 {
    return None
  }
  let mut result = 0
  for ch in chars {
    if ch < '0' || ch > '9' {
      return None
    }
    result = result * 10 + (ch.to_int() - '0'.to_int())
  }
  Some(result)
}

///|
fn parse_command(arguments : Array[String]) -> ArgumentResult {
  if arguments.length() == 0 ||
    arguments[0] == "--help" ||
    arguments[0] == "-h" ||
    arguments[0] == "help" {
    return { options: None, help: true, error: None, }
  }
  let action = arguments[0]
  if action != "check" &&
    action != "build" &&
    action != "explain" &&
    action != "audit" {
    return {
      options: None,
      help: false,
      error: Some("unknown command `\{action}`"),
    }
  }
  let mut input : String? = None
  let mut output : String? = None
  let mut source_map : String? = None
  let mut manifest : String? = None
  let mut audit_budget : Int? = None
  let mut policy_path : String? = None
  let required_markers : Array[String] = []
  let forbidden_markers : Array[String] = []
  let mut report : String? = None
  let mut json = false
  let mut deny_warnings = false
  let definitions : Array[@semantics.Definition] = []
  let mut index = 1
  while index < arguments.length() {
    let argument = arguments[index]
    if argument == "--define" {
      index += 1
      if index >= arguments.length() {
        return {
          options: None,
          help: false,
          error: Some("`--define` expects name=value"),
        }
      }
      match parse_definition(arguments[index]) {
        Some(definition) => definitions.push(definition)
        None =>
          return {
            options: None,
            help: false,
            error: Some(
              "invalid definition `\{arguments[index]}`; expected name=value",
            ),
          }
      }
    } else if argument == "--json" {
      if action != "audit" {
        return {
          options: None,
          help: false,
          error: Some("`--json` is only valid with the `audit` command"),
        }
      }
      json = true
    } else if argument == "--require" {
      if action != "audit" {
        return {
          options: None,
          help: false,
          error: Some("`--require` is only valid with the `audit` command"),
        }
      }
      index += 1
      if index >= arguments.length() || arguments[index] == "" {
        return {
          options: None,
          help: false,
          error: Some("`--require` expects a non-empty marker"),
        }
      }
      required_markers.push(arguments[index])
    } else if argument == "--forbid" {
      if action != "audit" {
        return {
          options: None,
          help: false,
          error: Some("`--forbid` is only valid with the `audit` command"),
        }
      }
      index += 1
      if index >= arguments.length() || arguments[index] == "" {
        return {
          options: None,
          help: false,
          error: Some("`--forbid` expects a non-empty marker"),
        }
      }
      forbidden_markers.push(arguments[index])
    } else if argument == "--deny-warnings" {
      if action != "audit" {
        return {
          options: None,
          help: false,
          error: Some(
            "`--deny-warnings` is only valid with the `audit` command",
          ),
        }
      }
      deny_warnings = true
    } else if argument == "--policy" {
      if action != "audit" {
        return {
          options: None,
          help: false,
          error: Some("`--policy` is only valid with the `audit` command"),
        }
      }
      index += 1
      if index >= arguments.length() ||
        arguments[index] == "" ||
        arguments[index].has_prefix("-") {
        return {
          options: None,
          help: false,
          error: Some("`--policy` expects a path"),
        }
      }
      policy_path = Some(arguments[index])
    } else if argument == "--budget" {
      if action != "audit" {
        return {
          options: None,
          help: false,
          error: Some("`--budget` is only valid with the `audit` command"),
        }
      }
      index += 1
      if index >= arguments.length() {
        return {
          options: None,
          help: false,
          error: Some("`--budget` expects a positive integer"),
        }
      }
      match parse_positive_integer(arguments[index]) {
        Some(value) if value > 0 => audit_budget = Some(value)
        _ =>
          return {
            options: None,
            help: false,
            error: Some("`--budget` expects a positive integer"),
          }
      }
    } else if argument == "--report" {
      if action != "audit" {
        return {
          options: None,
          help: false,
          error: Some("`--report` is only valid with the `audit` command"),
        }
      }
      index += 1
      if index >= arguments.length() ||
        arguments[index] == "" ||
        arguments[index].has_prefix("-") {
        return {
          options: None,
          help: false,
          error: Some("`--report` expects a path"),
        }
      }
      report = Some(arguments[index])
    } else if argument == "-o" ||
      argument == "--output" ||
      argument == "--source-map" ||
      argument == "--manifest" {
      index += 1
      if index >= arguments.length() {
        return {
          options: None,
          help: false,
          error: Some("`\{argument}` expects a path"),
        }
      }
      if arguments[index] == "" || arguments[index].has_prefix("-") {
        return {
          options: None,
          help: false,
          error: Some("`\{argument}` expects a path"),
        }
      }
      if argument == "-o" || argument == "--output" {
        output = Some(arguments[index])
      } else if argument == "--source-map" {
        source_map = Some(arguments[index])
      } else {
        manifest = Some(arguments[index])
      }
    } else if argument.has_prefix("-") {
      return {
        options: None,
        help: false,
        error: Some("unknown option `\{argument}`"),
      }
    } else if input is Some(_) {
      return {
        options: None,
        help: false,
        error: Some("only one input path is accepted"),
      }
    } else {
      input = Some(argument)
    }
    index += 1
  }
  if action != "build" &&
    (output is Some(_) || source_map is Some(_) || manifest is Some(_)) {
    return {
      options: None,
      help: false,
      error: Some("output paths are only valid with the `build` command"),
    }
  }
  if action == "audit" && audit_budget is None && policy_path is None {
    return {
      options: None,
      help: false,
      error: Some("the `audit` command requires `--policy` or `--budget`"),
    }
  }
  if action != "audit" &&
    (
      audit_budget is Some(_) ||
      policy_path is Some(_) ||
      required_markers.length() > 0 ||
      forbidden_markers.length() > 0 ||
      report is Some(_) ||
      json ||
      deny_warnings
    ) {
    return {
      options: None,
      help: false,
      error: Some("audit options are only valid with the `audit` command"),
    }
  }
  match input {
    Some(path) =>
      if path == "" {
        {
          options: None,
          help: false,
          error: Some("input path must not be empty"),
        }
      } else {
        {
          options: Some({
            action,
            input: path,
            output,
            source_map,
            manifest,
            definitions,
            policy_path,
            audit_budget,
            required_markers,
            forbidden_markers,
            report,
            json,
            deny_warnings,
          }),
          help: false,
          error: None,
        }
      }
    None =>
      {
        options: None,
        help: false,
        error: Some("a root .ctx input path is required"),
      }
  }
}

///|
fn usage() -> String {
  "Usage: mooncontext <check|build|explain> <input.ctx> [options]\n       mooncontext audit <context.md> (--policy path | --budget N) [options]\n\nOptions:\n  --define name=value   Override a context variable (repeatable)\n  -o, --output path     Write build artifact to a file (build only)\n  --source-map path     Write source-map JSON (build only)\n  --manifest path       Write build-manifest JSON (build only)\n  --policy path         Load a reusable JSON audit policy (audit)\n  --budget N            Maximum characters; overrides policy (audit)\n  --require marker      Append required text (repeatable, audit)\n  --forbid marker       Append forbidden text (repeatable, audit)\n  --deny-warnings       Treat audit warnings as failures (audit)\n  --report path         Write the audit report to a file (audit)\n  --json                Emit a machine-readable audit report (audit)\n  -h, --help            Show this help\n"
}
