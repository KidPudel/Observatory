# Repository instructions for agents

Before changing this repository, read
[`docs/readme-map.md`](docs/readme-map.md) and follow its task-specific reading
route.

## Build and launch

Run `./scripts/run.sh` from the repository root to build the Debug configuration
into `.build` and launch Observatory. Opening Xcode is optional unless the task
requires its debugger, previews, or other IDE-only tools.

For every code implementation task:

1. Read [`docs/current.md`](docs/current.md) for the current release state.
2. Read the relevant specification before editing code.
3. Keep behavior consistent with the active specifications.
4. Update `docs/current.md` when the release state or next action changes.
5. Append a concise implementation entry to `docs/progress.md` before finishing:
   - record what changed;
   - record verification performed;
   - record the next concrete task or any blocker.
6. Update `docs/implementation-plan.md` only when sequencing, scope, or
   dependencies change.
7. Do not mark a feature verified until its acceptance criteria have been
   verified.

If documents disagree, use the authority order documented in
`docs/readme-map.md` and record the resolution in `docs/progress.md`.
