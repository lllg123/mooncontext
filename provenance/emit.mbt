///|
fn character_length(value : String) -> Int {
  let mut length = 0
  for _ in value {
    length += 1
  }
  length
}

///|
fn content_length(content : @ir.Content) -> Int {
  match content {
    Inline(value) | File(value) => character_length(value)
  }
}

///|
fn source_files(sources : Array[@resolver.ResolvedSource]) -> Array[SourceFile] {
  let files = sources.map(source => { id: source.id, path: source.path, })
  for index in 1..<files.length() {
    let mut current = index
    while current > 0 && files[current].id.value < files[current - 1].id.value {
      let previous = files[current - 1]
      files[current - 1] = files[current]
      files[current] = previous
      current -= 1
    }
  }
  files
}

///|
fn rendered_section(context : @ir.Context, section_id : String) -> @ir.Section? {
  for section in context.sections {
    if section.name == section_id {
      return Some(section)
    }
  }
  None
}

///|
fn source_is_valid(
  span : @diagnostics.Span,
  sources : Array[@resolver.ResolvedSource],
) -> Bool {
  for source in sources {
    if source.id == span.source {
      let source_length = character_length(source.text)
      return span.start >= 0 &&
        span.end >= span.start &&
        span.end <= source_length
    }
  }
  false
}

///|
fn source_mappings(
  context : @ir.Context,
  sources : Array[@resolver.ResolvedSource],
  layouts : Array[@renderer.RenderedSection],
) -> Array[SourceMapping] {
  let mappings : Array[SourceMapping] = []
  for layout in layouts {
    match rendered_section(context, layout.section_id) {
      Some(section) => {
        let section_length = content_length(section.content)
        for segment in section.provenance {
          if segment.content_start >= 0 &&
            segment.content_end >= segment.content_start &&
            segment.content_end <= section_length &&
            source_is_valid(segment.source, sources) {
            mappings.push({
              section_id: section.name,
              generated_start: layout.content_start + segment.content_start,
              generated_end: layout.content_start + segment.content_end,
              source: segment.source,
            })
          }
        }
      }
      None => ()
    }
  }
  mappings
}

///|
/// Emit the selected artifact, source map, and deterministic build manifest.
///
/// The manifest is produced even when allocation failed (`plan` is `None`); in
/// that case no artifact or generated source mappings are returned. Source
/// paths use the normalized, first-discovery order supplied by the resolver.
///
/// ```mbt check
/// test {
///   let context : @ir.Context = {
///     identity: "demo",
///     output: @ir.OutputFormat::PlainText,
///     char_budget: 20,
///     sections: [],
///   }
///   let empty_plan : @ir.SelectionPlan = {
///     selected_section_ids: [],
///     omitted_sections: [],
///     required_chars: 0,
///     optional_chars: 0,
///     total_chars: 0,
///     remaining_chars: 20,
///   }
///   let result = emit(context, Some(empty_plan), [], [])
///   assert_eq(result.artifact, Some(""))
///   assert_eq(result.manifest.context_identity, "demo")
/// }
/// ```
pub fn emit(
  context : @ir.Context,
  plan : @ir.SelectionPlan?,
  sources : Array[@resolver.ResolvedSource],
  diagnostics : Array[@diagnostics.Diagnostic],
) -> BuildOutput {
  let files = source_files(sources)
  let (artifact, mappings) = match plan {
    Some(selection) => {
      let rendered = @renderer.render_with_layout(context, selection)
      (
        Some(rendered.text),
        source_mappings(context, sources, rendered.sections),
      )
    }
    None => (None, [])
  }
  {
    artifact,
    source_map: { files, mappings, },
    manifest: {
      context_identity: context.identity,
      inputs: files.map(file => file),
      output: context.output,
      char_budget: context.char_budget,
      selection: plan,
      diagnostics,
    },
  }
}
