# Release process

MoonContext 0.2.0 is a source package for MoonBit. A release is complete only
after the GitHub commit, CI, and Mooncakes publication have been verified.

## Verify from a clean checkout

Use a MoonBit toolchain with `moonc` 0.10.14 or newer. From the repository root:

```sh
moon version --all
moon update
moon fmt --check
moon check --target all --deny-warn --warn-list=-implicit_impl_as_method-test_unqualified_package
moon build --target all
moon test --target all --warn-list=-implicit_impl_as_method-test_unqualified_package
moon info
moon run examples/release_gate --target native -- pass
```

The example uses a pinned historical Git commit, so CI and local clones need
its history (`git fetch --unshallow` if the clone is shallow). It must produce
`_build/release_gate/approved-context.md`. The `stale`, `unsafe`, and `leak`
modes must fail without leaving that artifact. See [the trust boundary](trust-boundary.md)
before connecting the gate to a real model or release system.

## Publish

After the version in `moon.mod` and `CHANGELOG.md` agrees, CI is green, and
the intended GitHub commit is visible:

```sh
moon whoami
moon publish
```

Confirm that version 0.2.0 appears under `lllg123/mooncontext` on
[Mooncakes](https://mooncakes.io/) and that a fresh project can add the
published package:

```sh
moon add lllg123/mooncontext@0.2.0
moon check --target all
```

Only after publication is confirmed, create and push the matching Git tag
`v0.2.0`. Do not publish a local build artifact containing private context:
the CI artifact is made solely from public fixture text.
