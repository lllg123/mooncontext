///|
priv struct CommandOptions {
  action : String
  input : String
  output : String?
  source_map : String?
  manifest : String?
  definitions : Array[@semantics.Definition]
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
fn parse_command(arguments : Array[String]) -> ArgumentResult {
  if arguments.length() == 0 ||
    arguments[0] == "--help" ||
    arguments[0] == "-h" ||
    arguments[0] == "help" {
    return { options: None, help: true, error: None, }
  }
  let action = arguments[0]
  if action != "check" && action != "build" && action != "explain" {
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
  "Usage: mooncontext <check|build|explain> <input.ctx> [options]\n\nOptions:\n  --define name=value   Override a context variable (repeatable)\n  -o, --output path     Write build artifact to a file (build only)\n  --source-map path     Write source-map JSON (build only)\n  --manifest path       Write build-manifest JSON (build only)\n  -h, --help            Show this help\n"
}
