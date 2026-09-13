///|
/// Selection plan or ordered diagnostics produced by budget allocation.
pub(all) struct AllocationResult {
  plan : @ir.SelectionPlan?
  diagnostics : Array[@diagnostics.Diagnostic]
} derive(Debug)
