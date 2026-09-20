///|
priv struct Compilation {
  sources : Array[@resolver.ResolvedSource]
  context : @ir.Context?
  plan : @ir.SelectionPlan?
  diagnostics : Array[@diagnostics.Diagnostic]
}

///|
extern "C" fn process_exit(code : Int) -> Unit = "exit"

///|
fn parent_directory(path : String) -> String {
  let normalized = path.replace_all(old="\\", new="/")
  let chars = [ for ch in normalized => ch ]
  let mut separator = -1
  for index, ch in chars {
    if ch == '/' {
      separator = index
    }
  }
  if separator < 0 {
    "."
  } else if separator == 0 {
    "/"
  } else {
    let parent = StringBuilder()
    for index in 0..<separator {
      parent.write_char(chars[index])
    }
    parent.to_string()
  }
}

///|
async fn read_source_within(root : String, path : String) -> String? {
  if root == "" {
    return None
  }
  try {
    let canonical = @fs.realpath(path)
    let canonical_root = root.replace_all(old="\\", new="/")
    let canonical_path = canonical.replace_all(old="\\", new="/")
    let prefix = if canonical_root.has_suffix("/") {
      canonical_root
    } else {
      canonical_root + "/"
    }
    if canonical_path.has_prefix(prefix) {
      Some(@fs.read_file(canonical).text())
    } else {
      None
    }
  } catch {
    _ => None
  }
}

///|
fn has_errors(diagnostics : Array[@diagnostics.Diagnostic]) -> Bool {
  diagnostics.any(diagnostic => {
    diagnostic.severity == @diagnostics.Severity::Error
  })
}

///|
async fn report_diagnostics(
  sources : Array[@resolver.ResolvedSource],
  diagnostics : Array[@diagnostics.Diagnostic],
) -> Unit {
  let source_map = @diagnostics.SourceMap::new()
  for source in sources {
    ignore(source_map.add(source.path, source.text))
  }
  for diagnostic in diagnostics {
    @stdio.stderr.write(source_map.format(diagnostic))
  }
}

///|
fn[T] append_all(target : Array[T], values : Array[T]) -> Unit {
  for value in values {
    target.push(value)
  }
}

///|
fn file_source_id(
  path : String,
  sources : Array[@resolver.ResolvedSource],
) -> @diagnostics.SourceId? {
  for source in sources {
    if source.path == path {
      return Some(source.id)
    }
  }
  None
}

///|
fn string_length(value : String) -> Int {
  let mut length = 0
  for _ in value {
    length += 1
  }
  length
}

///|
async fn load_content_files(
  document : @syntax.DocumentSyntax,
  sources : Array[@resolver.ResolvedSource],
  diagnostics : Array[@diagnostics.Diagnostic],
  read_source : async (String) -> String?,
) -> @syntax.DocumentSyntax {
  let declarations : Array[@syntax.DeclarationSyntax] = []
  let content_ids : Map[String, @diagnostics.SourceId] = Map([])
  for declaration in document.declarations {
    match declaration {
      @syntax.DeclarationSyntax::Section(section) => {
        let contents : Array[@syntax.SectionContentSyntax] = []
        for content in section.contents {
          match content {
            @syntax.SectionContentSyntax::Text(_, _) => contents.push(content)
            @syntax.SectionContentSyntax::File(path, _) => {
              let loaded_id = match content_ids.get(path.value) {
                Some(id) => Some(id)
                None =>
                  match read_source(path.value) {
                    Some(text) => {
                      let id = match file_source_id(path.value, sources) {
                        Some(existing) => existing
                        None => {
                          let next_id = @diagnostics.SourceId::{
                            value: sources.length(),
                          }
                          sources.push({ id: next_id, path: path.value, text, })
                          next_id
                        }
                      }
                      content_ids[path.value] = id
                      Some(id)
                    }
                    None => {
                      diagnostics.push(
                        @diagnostics.Diagnostic::new(
                          @diagnostics.Severity::Error,
                          code="E3001",
                          message="content source `\{path.value}` was not found",
                          primary=path.span,
                          help="make the file available inside the compilation root",
                        ),
                      )
                      None
                    }
                  }
              }
              match loaded_id {
                Some(id) => {
                  let text = match sources.get(id.value) {
                    Some(source) => source.text
                    None => ""
                  }
                  let source_span = @diagnostics.Span::new(
                    id,
                    start=0,
                    end=string_length(text),
                  )
                  contents.push(
                    @syntax.SectionContentSyntax::Text(
                      { value: text, span: source_span, },
                      source_span,
                    ),
                  )
                }
                None => ()
              }
            }
          }
        }
        declarations.push(
          @syntax.DeclarationSyntax::Section({
            name: section.name,
            modifiers: section.modifiers,
            contents,
            span: section.span,
          }),
        )
      }
      other => declarations.push(other)
    }
  }
  { declarations, }
}

///|
async fn compile(options : CommandOptions) -> Compilation {
  let root_path = parent_directory(options.input)
  let canonical_root = @fs.realpath(root_path) catch { _ => "" }
  let provider : async (String) -> String? = path => {
    read_source_within(canonical_root, path)
  }
  let resolved = @resolver.resolve_with_provider(options.input, provider)
  let sources = resolved.document.sources
  let diagnostics = resolved.diagnostics
  if sources.length() == 0 {
    return { sources, context: None, plan: None, diagnostics, }
  }
  if has_errors(diagnostics) {
    return { sources, context: None, plan: None, diagnostics, }
  }
  let root_id = sources[0].id
  append_all(
    diagnostics,
    @semantics.validate(
      root_id,
      { declarations: resolved.document.declarations, },
      @semantics.SourceKind::Root,
    ).diagnostics,
  )
  for index in 1..<sources.length() {
    let source = sources[index]
    let parsed = @syntax.parse(source.id, source.text)
    let included = @semantics.validate(
      source.id,
      parsed.document,
      @semantics.SourceKind::Included,
    )
    for diagnostic in included.diagnostics {
      if diagnostic.code == "E4004" &&
        diagnostic.message == "included files cannot declare root configuration" {
        diagnostics.push(diagnostic)
      }
    }
  }
  if has_errors(diagnostics) {
    return { sources, context: None, plan: None, diagnostics, }
  }
  let document = load_content_files(
    { declarations: resolved.document.declarations, },
    sources,
    diagnostics,
    provider,
  )
  if has_errors(diagnostics) {
    return { sources, context: None, plan: None, diagnostics, }
  }
  let evaluation = @semantics.evaluate(document, options.definitions)
  append_all(diagnostics, evaluation.diagnostics)
  if has_errors(diagnostics) {
    return { sources, context: None, plan: None, diagnostics, }
  }
  match @ir.lower(document, evaluation) {
    Some(context) => {
      let allocation = @budget.allocate(context)
      append_all(diagnostics, allocation.diagnostics)
      { sources, context: Some(context), plan: allocation.plan, diagnostics, }
    }
    None => {
      diagnostics.push(
        @diagnostics.Diagnostic::new(
          @diagnostics.Severity::Error,
          code="E5001",
          message="could not lower the checked document to context IR",
          primary=@diagnostics.Span::new(root_id, start=0, end=0),
        ),
      )
      { sources, context: None, plan: None, diagnostics, }
    }
  }
}

///|
fn json_quote(value : String) -> String {
  let output = StringBuilder()
  output.write_char('"')
  for ch in value {
    match ch {
      '"' => output.write_string("\\\"")
      '\\' => output.write_string("\\\\")
      '\n' => output.write_string("\\n")
      '\r' => output.write_string("\\r")
      '\t' => output.write_string("\\t")
      value => output.write_char(value)
    }
  }
  output.write_char('"')
  output.to_string()
}

///|
fn source_map_json(value : @provenance.SourceMap) -> String {
  let output = StringBuilder()
  output.write_string("{\"files\":[")
  for index, file in value.files {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string("{\"id\":")
    output.write_string(file.id.value.to_string())
    output.write_string(",\"path\":")
    output.write_string(json_quote(file.path))
    output.write_char('}')
  }
  output.write_string("],\"mappings\":[")
  for index, mapping in value.mappings {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string("{\"section_id\":")
    output.write_string(json_quote(mapping.section_id))
    output.write_string(",\"generated_start\":")
    output.write_string(mapping.generated_start.to_string())
    output.write_string(",\"generated_end\":")
    output.write_string(mapping.generated_end.to_string())
    output.write_string(",\"source\":{\"file\":")
    output.write_string(mapping.source.source.value.to_string())
    output.write_string(",\"start\":")
    output.write_string(mapping.source.start.to_string())
    output.write_string(",\"end\":")
    output.write_string(mapping.source.end.to_string())
    output.write_string("}}")
  }
  output.write_string("]}\n")
  output.to_string()
}

///|
fn output_format_name(value : @ir.OutputFormat) -> String {
  match value {
    @ir.OutputFormat::Markdown => "markdown"
    @ir.OutputFormat::PlainText => "text"
  }
}

///|
fn manifest_json(value : @provenance.BuildManifest) -> String {
  let output = StringBuilder()
  output.write_string("{\"context_identity\":")
  output.write_string(json_quote(value.context_identity))
  output.write_string(",\"inputs\":[")
  for index, file in value.inputs {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string("{\"id\":")
    output.write_string(file.id.value.to_string())
    output.write_string(",\"path\":")
    output.write_string(json_quote(file.path))
    output.write_char('}')
  }
  output.write_string("],\"output\":")
  output.write_string(json_quote(output_format_name(value.output)))
  output.write_string(",\"char_budget\":")
  output.write_string(value.char_budget.to_string())
  output.write_string(",\"selection\":")
  match value.selection {
    None => output.write_string("null")
    Some(selection) => {
      output.write_string("{\"selected_section_ids\":[")
      for index, id in selection.selected_section_ids {
        if index > 0 {
          output.write_char(',')
        }
        output.write_string(json_quote(id))
      }
      output.write_string("],\"omitted_sections\":[")
      for index, omitted in selection.omitted_sections {
        if index > 0 {
          output.write_char(',')
        }
        output.write_string("{\"section_id\":")
        output.write_string(json_quote(omitted.section_id))
        output.write_string(",\"reason\":\"budget_limit\"}")
      }
      output.write_string("],\"required_chars\":")
      output.write_string(selection.required_chars.to_string())
      output.write_string(",\"optional_chars\":")
      output.write_string(selection.optional_chars.to_string())
      output.write_string(",\"total_chars\":")
      output.write_string(selection.total_chars.to_string())
      output.write_string(",\"remaining_chars\":")
      output.write_string(selection.remaining_chars.to_string())
      output.write_char('}')
    }
  }
  output.write_string(",\"diagnostics\":[")
  for index, diagnostic in value.diagnostics {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string("{\"severity\":")
    output.write_string(
      json_quote(
        match diagnostic.severity {
          @diagnostics.Severity::Error => "error"
          @diagnostics.Severity::Warning => "warning"
        },
      ),
    )
    output.write_string(",\"code\":")
    output.write_string(json_quote(diagnostic.code))
    output.write_string(",\"message\":")
    output.write_string(json_quote(diagnostic.message))
    output.write_string(",\"source\":")
    output.write_string(diagnostic.primary.source.value.to_string())
    output.write_string(",\"start\":")
    output.write_string(diagnostic.primary.start.to_string())
    output.write_string(",\"end\":")
    output.write_string(diagnostic.primary.end.to_string())
    output.write_char('}')
  }
  output.write_string("]}\n")
  output.to_string()
}

///|
async fn write_file_or_stdout(path : String?, text : String) -> Bool {
  match path {
    Some(value) =>
      try {
        @fs.write_file(
          value,
          @utf8.encode(text),
          create_mode=@fs.CreateMode::CreateOrTruncate,
        )
        true
      } catch {
        error => {
          @stdio.stderr.write("output write error: \{error}\n")
          false
        }
      }
    None => {
      @stdio.stdout.write(text)
      true
    }
  }
}

///|
fn audit_json(path : String, report : @audit.Report) -> String {
  let output = StringBuilder()
  output.write_string("{\"path\":")
  output.write_string(json_quote(path))
  output.write_string(",\"character_count\":")
  output.write_string(report.character_count.to_string())
  output.write_string(",\"heading_count\":")
  output.write_string(report.heading_count.to_string())
  output.write_string(",\"issues\":[")
  for index, issue in report.issues {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string("{\"severity\":")
    output.write_string(
      json_quote(
        match issue.severity {
          @audit.Severity::Error => "error"
          @audit.Severity::Warning => "warning"
        },
      ),
    )
    output.write_string(",\"code\":")
    output.write_string(json_quote(issue.code))
    output.write_string(",\"message\":")
    output.write_string(json_quote(issue.message))
    output.write_string(",\"line\":")
    output.write_string(issue.line.to_string())
    output.write_string(",\"column\":")
    output.write_string(issue.column.to_string())
    output.write_char('}')
  }
  output.write_string("]}\n")
  output.to_string()
}

///|
fn effective_audit_policy(
  options : CommandOptions,
  loaded : @audit.PolicyConfig?,
) -> (@audit.Policy, Bool)? {
  let budget = match options.audit_budget {
    Some(value) => value
    None =>
      match loaded {
        Some(config) => config.policy.char_budget
        None => return None
      }
  }
  let required_markers : Array[String] = []
  let forbidden_markers : Array[String] = []
  let mut deny_warnings = options.deny_warnings
  match loaded {
    Some(config) => {
      append_all(required_markers, config.policy.required_markers)
      append_all(forbidden_markers, config.policy.forbidden_markers)
      deny_warnings = deny_warnings || config.deny_warnings
    }
    None => ()
  }
  append_all(required_markers, options.required_markers)
  append_all(forbidden_markers, options.forbidden_markers)
  Some(
    (
      @audit.Policy::with_forbidden(
        char_budget=budget,
        required_markers~,
        forbidden_markers~,
      ),
      deny_warnings,
    ),
  )
}

///|
async fn run_audit(options : CommandOptions) -> Unit {
  let loaded_policy = match options.policy_path {
    None => None
    Some(path) => {
      let policy_text = @fs.read_file(path).text() catch {
        error => {
          @stdio.stderr.write(
            "error: unable to read policy \{path}: \{error}\n",
          )
          process_exit(2)
          return
        }
      }
      match @audit.parse_policy_json(policy_text) {
        Ok(config) => Some(config)
        Err(message) => {
          @stdio.stderr.write("error: invalid policy \{path}: \{message}\n")
          process_exit(2)
          return
        }
      }
    }
  }
  let effective = match effective_audit_policy(options, loaded_policy) {
    Some(value) => value
    None => {
      @stdio.stderr.write("error: audit policy or budget is missing\n")
      process_exit(2)
      return
    }
  }
  let (policy, deny_warnings) = effective
  try {
    let text = @fs.read_file(options.input).text()
    let report = @audit.audit(text, policy)
    let output = if options.json {
      audit_json(options.input, report)
    } else {
      @audit.format_report(options.input, report)
    }
    let wrote = write_file_or_stdout(options.report, output)
    if !wrote {
      process_exit(2)
    }
    if report.has_failures(deny_warnings~) {
      process_exit(1)
    }
  } catch {
    error => {
      @stdio.stderr.write(
        "error: unable to read input \{options.input}: \{error}\n",
      )
      process_exit(2)
    }
  }
}

///|
async fn print_explanation(
  context : @ir.Context,
  plan : @ir.SelectionPlan,
) -> Unit {
  @stdio.stdout.write("Context: \{context.identity}\n")
  for section in context.sections {
    if plan.selected_section_ids.any(id => id == section.name) {
      let reason = if section.required {
        "required"
      } else {
        "priority=\{section.priority}"
      }
      @stdio.stdout.write("selected  \{section.name}  \{reason}\n")
    } else if plan.omitted_sections.any(item => item.section_id == section.name) {
      @stdio.stdout.write("omitted   \{section.name}  budget\n")
    }
  }
  @stdio.stdout.write(
    "characters required=\{plan.required_chars} optional=\{plan.optional_chars} total=\{plan.total_chars} remaining=\{plan.remaining_chars}\n",
  )
}

///|
async fn run(options : CommandOptions) -> Unit {
  if options.action == "audit" {
    run_audit(options)
    return
  }
  let result = compile(options)
  if result.sources.length() == 0 {
    @stdio.stderr.write("error: unable to read root input `\{options.input}`\n")
    process_exit(2)
  }
  report_diagnostics(result.sources, result.diagnostics)
  if has_errors(result.diagnostics) {
    process_exit(1)
  }
  match options.action {
    "check" => @stdio.stdout.write("checked `\{options.input}` successfully\n")
    "explain" =>
      match (result.context, result.plan) {
        (Some(context), Some(plan)) => print_explanation(context, plan)
        _ => {
          @stdio.stderr.write("could not explain an unsuccessful build\n")
          process_exit(1)
        }
      }
    "build" =>
      match (result.context, result.plan) {
        (Some(context), Some(plan)) => {
          let emitted = @provenance.emit(
            context,
            Some(plan),
            result.sources,
            result.diagnostics,
          )
          let mut succeeded = match emitted.artifact {
            Some(artifact) => write_file_or_stdout(options.output, artifact)
            None => false
          }
          if succeeded {
            match options.source_map {
              Some(path) =>
                succeeded = write_file_or_stdout(
                  Some(path),
                  source_map_json(emitted.source_map),
                )
              None => ()
            }
          }
          if succeeded {
            match options.manifest {
              Some(path) =>
                succeeded = write_file_or_stdout(
                  Some(path),
                  manifest_json(emitted.manifest),
                )
              None => ()
            }
          }
          if !succeeded {
            @stdio.stderr.write("failed to write one or more build outputs\n")
            process_exit(2)
          }
        }
        _ => {
          @stdio.stderr.write("build did not produce an artifact\n")
          process_exit(1)
        }
      }
    _ => ()
  }
}

///|
async fn main {
  let process_arguments = @env.args()
  let arguments : Array[String] = []
  for index in 1..<process_arguments.length() {
    arguments.push(process_arguments[index])
  }
  let parsed = parse_command(arguments)
  if parsed.help {
    @stdio.stdout.write(usage())
    return
  }
  match parsed.error {
    Some(message) => {
      @stdio.stderr.write("error: \{message}\n\n\{usage()}")
      process_exit(2)
    }
    None =>
      match parsed.options {
        Some(options) => run(options)
        None => ()
      }
  }
}
