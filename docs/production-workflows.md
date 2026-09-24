# Production audit workflows

MoonContext is most useful at the boundary between a renderer and a model
request. The renderer may be Markdown, Mustache, a knowledge-base exporter, or
an application-specific service. In production, keep that renderer unchanged
and make the final text a CI artifact:

1. render the context files;
2. audit every rendered artifact with one versioned policy;
3. retain the JSON report with the build;
4. review report changes before publishing.

The examples below use GitHub Actions, but the same four commands work in
GitLab CI, Buildkite, or a local release script.

## Pull-request gate

Store the policy beside the source that owns the safety contract. The policy
is intentionally ordinary JSON, so reviewers can see budget and forbidden
markers without learning a new template language.

~~~json
{
  "version": 1,
  "char_budget": 12000,
  "required_markers": ["System rules", "Evidence"],
  "forbidden_markers": ["TODO", "sk-", "localhost"],
  "deny_warnings": true
}
~~~

After the application renderer writes its outputs into build/context, a
minimal pull-request job can audit the whole directory:

~~~yaml
name: Context audit

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - name: Check out source
        uses: actions/checkout@v4

      - name: Install MoonBit
        uses: hustcer/setup-moonbit@v1
        with:
          version: "0.10.11+6ff76a5f9"
          core-version: "0.10.11+6ff76a5f9"

      - name: Resolve dependencies
        run: moon update

      - name: Render application contexts
        run: ./scripts/render-contexts.sh build/context

      - name: Audit rendered contexts
        run: |
          moon run cmd/main -- audit \
            build/context/system.md \
            build/context/review.md \
            --policy policy/context-audit.json \
            --json \
            --report build/context-audit.json

      - name: Retain audit report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: context-audit-report
          path: build/context-audit.json
          if-no-files-found: error
~~~

The audit step fails with status 1 when a context violates the policy and
status 2 when an input, policy, or output is unavailable. The artifact step
uses always so a failed report remains available for diagnosis. Do not upload
the rendered context itself when it may contain confidential customer data;
upload only the report if the report's paths and messages are safe for the
repository's CI logs.

## Batch audit after a knowledge-base build

Knowledge-base and agent workflows often produce a variable number of files.
Generate an explicit file list rather than auditing a broad directory
implicitly. This makes the report reviewable and prevents temporary files from
silently entering a model request.

~~~sh
moon run cmd/main -- audit \
  build/context/agent.md \
  build/context/code-review.md \
  build/context/knowledge-base.md \
  --policy policy/context-audit.json \
  --json \
  --report build/context-audit.json
~~~

The batch report keeps one artifact per successful input in argument order.
Unreadable inputs appear in errors and make the command exit with status 2;
content failures remain status 1. Retain the report before evaluating the
status, and never promote a partial batch as if it were complete.

For local reproduction, use the same policy and exact paths:

~~~sh
moon update
moon run cmd/main -- audit \
  examples/audit/context.md examples/audit/context-minimal.md \
  --policy examples/audit/policy.json \
  --json --report _build/context-audit.json
~~~

## Review changes between builds

When a release produces a new report, compare it with the report from the
previous approved build. The storage-specific download step is deliberately
outside MoonContext; it can use a CI artifact, an object store, or a signed
release asset.

~~~sh
# Replace this with the CI artifact or object-store command used by your team.
download-approved-report build/approved/context-audit.json
moon run cmd/main -- audit \
  build/context/system.md build/context/review.md \
  --policy policy/context-audit.json \
  --json --report build/context-audit-current.json
moon run cmd/main -- diff \
  build/approved/context-audit.json \
  build/context-audit-current.json \
  --json --report build/context-audit-diff.json
~~~

diff aligns artifacts by path and records additions, removals, fingerprint
changes, issue-code changes, and batch read-error changes. A no-change result
exits 0. Any change exits 1 so the release can require a human review. Invalid
JSON or an unavailable report exits 2 and should be treated as an operational
failure, not as approval.

The text form is convenient for a review comment:

~~~sh
moon run cmd/main -- diff \
  build/approved/context-audit.json build/context-audit-current.json
~~~

The JSON form is better for release metadata. Retain both the diff report and
the current audit report with the immutable build identifier.

## Release checklist

Before promoting a context build:

- pin the MoonBit and core versions in CI;
- run moon update from a clean checkout;
- render contexts with the production configuration, not test fixtures;
- audit all intended artifacts with a reviewed policy;
- retain the JSON audit report and, when applicable, the diff report;
- stop on status 1 or 2 and record who approved a changed report;
- avoid putting secrets or full customer context in CI logs and artifacts.

The report fingerprint is a SHA-256 digest of the exact UTF-8 text that was
audited. It helps connect a release record to the generated artifact, but it is
not a signature or an authorization mechanism.
