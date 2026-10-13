///|
/// One excerpt and the trusted fingerprint of the complete source snapshot.
/// The caller is responsible for loading the source from its declared path.
pub(all) struct Evidence {
  id : String
  path : String
  source_text : String
  excerpt : String
  expected_fingerprint : String
}

///|
/// Inputs to a canonical, evidence-backed model context.
pub(all) struct Request {
  system_rules : String
  question : String
  evidence : Array[Evidence]
}

///|
/// Audit contract for one evidence-backed context bundle.
pub(all) struct Policy {
  allowed_root : String
  text_policy : @audit.Policy
  deny_warnings : Bool
  required_rules : Array[String]
  forbidden_instructions : Array[String]
}

///|
/// A source reference safe to retain without copying source text into a report.
pub(all) struct SourceRecord {
  id : String
  path : String
  source_fingerprint : String
  excerpt_fingerprint : String
}

///|
pub(all) struct Finding {
  code : String
  source_id : String
  message : String
}

///|
/// Complete deterministic gate result, including the exact final-text digest.
pub(all) struct Report {
  audit : @audit.Report
  sources : Array[SourceRecord]
  findings : Array[Finding]
}

///|
pub fn Report::has_failures(self : Report, deny_warnings~ : Bool) -> Bool {
  self.findings.length() > 0 || self.audit.has_failures(deny_warnings~)
}

///|
/// Only `approve` constructs this value; delivery accepts this type, not raw text.
pub struct ApprovedContext {
  priv payload : String
  priv report : Report
}

///|
pub fn ApprovedContext::report(self : ApprovedContext) -> Report {
  self.report
}

///|
/// Invoke a synchronous publisher or model-adapter callback with the audited text.
pub fn ApprovedContext::deliver(
  self : ApprovedContext,
  send : (String) -> Unit,
) -> Unit {
  send(self.payload)
}

///|
/// Read the approved payload for an asynchronous SDK adapter.
pub fn ApprovedContext::text(self : ApprovedContext) -> String {
  self.payload
}
