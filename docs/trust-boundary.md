# Evidence and release boundary

MoonContext's `audit` CLI checks a rendered artifact. Its `gate` package adds
evidence checks; `gate/git` is the native-only loader for a reviewed Git
snapshot. They are complementary, not alternate template engines.

The trusted `gate/git.Policy` fixes a full 40-character commit ID and one
source ID, repository-relative path, and SHA-256 digest per source. A request
supplies only its task, system rules, source IDs, and excerpts. The loader
passes separate arguments to Git (never through a shell), checks that the
revision is a commit and that each path is an ordinary Git blob rather than
a symlink or directory, then reads that blob. The pure `gate` package verifies
its digest and that each excerpt occurs in its complete source. It checks
required system rules in the system-rule field, instruction-only forbidden
markers in the rule/task fields, and global forbidden markers in the complete
rendered context. Only then does it return an opaque approved snapshot.

The runnable example writes an artifact only from that approved value and
reads it back to verify the exact audited fingerprint. It clears a previous
artifact before every attempt, including failed ones. GitHub Actions uploads
the example artifact only after all checks pass. In a production system, the
model or release adapter must consume that approved artifact, not independently
rebuild a similar-looking string.

Limits: the reviewed policy and local Git repository are trust anchors. A
compromised policy, malicious repository substitution, or a consumer that
ignores the approved artifact lies outside this library's guarantee. SHA-256
is a content identifier, not a signature. The character budget is not a
model tokenizer count; forbidden strings are exact, case-sensitive matches,
not general secret detection or prompt-injection prevention. Ordinary code
examples inside Markdown fences may contain literal `${...}` or `{{...}}`;
unresolved-placeholder checks apply to surrounding prose. If a token such as
`TODO` may appear legitimately in cited code, configure it as an
instruction-only marker in `gate.Policy`, not a global forbidden marker.
