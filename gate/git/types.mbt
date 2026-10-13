///|
/// A reviewed binding from source identity to an exact Git blob fingerprint.
pub(all) struct SourcePin {
  id : String
  path : String
  fingerprint : String
}

///|
/// The request can choose excerpts, but not source paths or expected digests.
pub(all) struct Citation {
  id : String
  excerpt : String
}

///|
pub(all) struct Request {
  system_rules : String
  question : String
  citations : Array[Citation]
}

///|
/// Treat this reviewed policy as trusted configuration, not request data.
/// `revision` must be a full 40-character Git commit ID.
pub(all) struct Policy {
  repo_root : String
  revision : String
  bundle : @gate.Policy
  pins : Array[SourcePin]
}

///|
pub(all) enum SnapshotFailure {
  InvalidPolicy(String)
  SourceUnavailable(String)
  Rejected(@gate.Report)
}

///|
/// An approved payload bound to one immutable repository revision.
pub struct ApprovedSnapshot {
  priv context : @gate.ApprovedContext
  priv revision : String
}

///|
pub fn ApprovedSnapshot::revision(self : ApprovedSnapshot) -> String {
  self.revision
}

///|
pub fn ApprovedSnapshot::report(self : ApprovedSnapshot) -> @gate.Report {
  self.context.report()
}

///|
pub fn ApprovedSnapshot::text(self : ApprovedSnapshot) -> String {
  self.context.text()
}
