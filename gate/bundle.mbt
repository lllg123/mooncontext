///|
fn add_finding(
  findings : Array[Finding],
  code : String,
  source_id : String,
  message : String,
) -> Unit {
  findings.push({ code, source_id, message, })
}

///|
fn quote_evidence(excerpt : String) -> String {
  let mut run = 0
  let mut maximum = 2
  for ch in excerpt {
    if ch == '~' {
      run += 1
      if run > maximum {
        maximum = run
      }
    } else {
      run = 0
    }
  }
  let fence = StringBuilder()
  for _ in 0..<(maximum + 1) {
    fence.write_char('~')
  }
  let delimiter = fence.to_string()
  "\{delimiter}\n\{excerpt}\n\{delimiter}\n"
}

///|
fn render(request : Request) -> String {
  let output = StringBuilder()
  output.write_string("# System rules\n")
  output.write_string(request.system_rules)
  output.write_string("\n\n# Evidence\n")
  for source in request.evidence {
    output.write_string("\n## Source \{source.id}\n")
    output.write_string("Path: \{source.path}\n")
    output.write_string(quote_evidence(source.excerpt))
  }
  output.write_string("\n# Task\n")
  output.write_string(request.question)
  output.write_char('\n')
  output.to_string()
}

///|
/// Verify pinned source snapshots and excerpts before approving the final text.
///
/// This checks the data supplied by a trusted loader; it does not authenticate
/// a Git revision or follow filesystem symlinks. The exact rendered payload is
/// fingerprinted by `@audit.audit`, then stored in the returned opaque value.
///
/// ```mbt check
/// test {
///   let source = "reviewed evidence"
///   let request : Request = {
///     system_rules: "Cite evidence.",
///     question: "Review the change.",
///     evidence: [
///       {
///         id: "E1",
///         path: "docs/review.md",
///         source_text: source,
///         excerpt: source,
///         expected_fingerprint: @audit.fingerprint(source),
///       },
///     ],
///   }
///   let policy : Policy = {
///     allowed_root: "docs",
///     text_policy: @audit.Policy::new(char_budget=1000, required_markers=[]),
///     deny_warnings: true,
///   }
///   assert_true(approve(request, policy) is Ok(_))
/// }
/// ```
pub fn approve(
  request : Request,
  policy : Policy,
) -> Result[ApprovedContext, Report] {
  let findings : Array[Finding] = []
  let sources : Array[SourceRecord] = []
  let ids : Map[String, Bool] = Map([])
  if request.evidence.length() == 0 {
    add_finding(findings, "G1001", "", "at least one cited source is required")
  }
  if !valid_relative_path(policy.allowed_root) {
    add_finding(
      findings, "G0001", "", "allowed root must be a canonical relative path",
    )
  }
  for evidence in request.evidence {
    if !valid_evidence_id(evidence.id) {
      add_finding(
        findings,
        "G1002",
        evidence.id,
        "source id must be ASCII letters, digits, `-` or `_`",
      )
    } else if ids.contains(evidence.id) {
      add_finding(findings, "G1003", evidence.id, "duplicate source id")
    } else {
      ids[evidence.id] = true
    }
    if !path_within_root(policy.allowed_root, evidence.path) {
      add_finding(
        findings,
        "G1004",
        evidence.id,
        "source path is outside the allowed root or is not canonical",
      )
    }
    let source_fingerprint = @audit.fingerprint(evidence.source_text)
    if evidence.expected_fingerprint != source_fingerprint {
      add_finding(
        findings,
        "G1005",
        evidence.id,
        "source snapshot differs from the pinned fingerprint",
      )
    }
    if evidence.excerpt == "" ||
      !evidence.source_text.contains(evidence.excerpt) {
      add_finding(
        findings,
        "G1006",
        evidence.id,
        "excerpt is empty or absent from the pinned source",
      )
    }
    sources.push({
      id: evidence.id,
      path: evidence.path,
      source_fingerprint,
      excerpt_fingerprint: @audit.fingerprint(evidence.excerpt),
    })
  }
  let payload = render(request)
  let audit = @audit.audit(payload, policy.text_policy)
  let report : Report = { audit, sources, findings, }
  if report.has_failures(deny_warnings=policy.deny_warnings) {
    Err(report)
  } else {
    Ok({ payload, report, })
  }
}
