# Observatory release checklist

Use this checklist for every GitHub release candidate.

## Automated gates

- [ ] Debug build passes.
- [ ] The complete automated test suite passes in the testable Debug
  configuration.
- [ ] The optimized Release configuration archives successfully.
- [ ] `./scripts/measure-sampler.sh` passes on a representative Mac.
- [ ] `./scripts/release.sh` creates an archive and matching checksum.
- [ ] `codesign --verify --deep --strict` passes for the archived app.
- [ ] `git diff --check` passes.

## Interaction and appearance

- [ ] Now and Tests work at `980 × 680` and `820 × 600`.
- [ ] System, Light, and Dark appearances preserve hierarchy and contrast.
- [ ] Reduce Motion, Reduce Transparency, and Increase Contrast remain complete.
- [ ] Keyboard traversal reaches navigation, rows, disclosure, charts,
  settings, recording controls, Saved Results, and deletion confirmation.
- [ ] VoiceOver announces destination selection, application totals, missing
  values, recording state, chart controls, and destructive actions.
- [ ] A direct trackpad pass confirms stable Now scrolling with a large
  expanded process group.

## Reliability and privacy

- [ ] A 30-minute populated Now run remains responsive and bounded.
- [ ] A complete multi-application test survives interruption and relaunch.
- [ ] Observer overhead remains within the documented collector budget.
- [ ] No Screen Recording or Input Monitoring request appears.
- [ ] Privacy, installation, and known-limitations documents match the build.

## Distribution

- [ ] Version and build numbers are intentional.
- [ ] ZIP filename and `.sha256` filename match the release notes.
- [ ] A clean macOS user account verifies the checksum, installs, approves, and
  runs the archive.
- [ ] The published GitHub release links the privacy disclosure, installation
  guide, and known limitations.

Do not mark Phase 9 verified until every required manual gate has evidence in
`docs/progress.md`.
