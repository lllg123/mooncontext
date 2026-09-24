# Release process

MoonContext 0.1.0 releases a verified source tag; CI does not publish platform
binaries. The tag contains the audit command, examples, policies, production
workflow guide, and the checks used to verify them. The release scope is
tracked in CHANGELOG.md.

## Reproduce a release check

Use the same MoonBit compiler version pinned in
[the CI workflow](../.github/workflows/ci.yml). The workflow installs
`0.10.11+6ff76a5f9` and resolves the exact dependency declared in `moon.mod`.
For a fresh checkout, run from the repository root:

```sh
moon version --all
moon update
moon fmt --check
moon check --target all --deny-warn
moon build --target all
moon test --target all
moon info
moon run cmd/main -- audit examples/audit/context.md --budget 1800 \
  --require "System rules" --require "Evidence" --forbid "TODO" \
  --deny-warnings
```

Before publishing to Mooncakes, set the `repository` field in `moon.mod` to the
public source repository, run the complete verification above, and publish the
same clean revision. Verify the published package from a fresh project rather
than relying only on the local checkout.

The runnable audit example and production workflows are documented in
[examples.md](examples.md) and
[production-workflows.md](production-workflows.md). The dependency update step
needs registry access on a fresh machine; subsequent checks and tests use the
resolved local dependency.

## Prepare and tag 0.1.0

The 0.1.0 scope is recorded in CHANGELOG.md. Before creating the tag, confirm
that the module metadata and the package version both report 0.1.0, and review
the release report produced by the verification commands above.

1. Review the changes since the previous tag and confirm that `moon.mod` and
   the package version both report 0.1.0.
2. Confirm the CI workflow passes on the exact commit to be released.
3. From a clean worktree, create and push an annotated semantic-version tag:

   ```sh
   git status --short
   git tag -a v0.1.0 -m "MoonContext v0.1.0"
   git push origin v0.1.0
   ```

4. Create a GitHub Release for that tag and summarize user-visible changes,
   migration notes, and known limitations. GitHub provides source archives for
   the tag; do not describe them as prebuilt CLI binaries.

If the MoonBit toolchain or dependency pin changes, update the CI workflow and
this guide together, then run the full fresh-checkout verification above.
