# Release process

MoonContext currently releases source tags; CI does not publish platform
binaries. A tagged source revision contains the audit command, examples, and
the workflow used to verify them.

## Reproduce a release check

Use the same MoonBit compiler version pinned in
[the CI workflow](../.github/workflows/ci.yml). The workflow installs
`0.10.11+6ff76a5f9` and resolves the exact dependency declared in `moon.mod`.
For a fresh checkout, run from the repository root:

```sh
moon version --all
moon update
moon fmt --check
moon check --deny-warn
moon test
moon run cmd/main -- audit examples/audit/context.md --budget 1800 \
  --require "System rules" --require "Evidence"
```

The runnable audit example and its expected behavior are documented in
[examples.md](examples.md). `moon update` needs registry access on a fresh
machine; subsequent checks and tests use the resolved local dependency.

## Prepare and tag a release

1. Review the changes since the previous tag and update `moon.mod`'s `version`
   when making a new version.
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
