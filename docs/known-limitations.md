# Observatory 0.1 known limitations

- macOS 14 or later is required. Apple silicon is the tested release target;
  Intel validation does not block the first personal release.
- GitHub builds are ad-hoc signed and not notarized. macOS requires a deliberate
  first-open confirmation and may ask again after an update.
- Protected or short-lived processes can make individual metrics unavailable.
  Observatory keeps the application visible and does not substitute zero.
- Application ownership inventory refreshes every five seconds while metrics
  update every second, so a newly spawned helper can join its application row
  late.
- Direct application activation can be rejected by macOS. Automatic
  foreground-idle tests retry with a public Launch Services fallback and record
  a visible failed round if activation still fails.
- `session.json` contains context and summaries, not raw one-second samples.
  SQLite in Application Support remains the timeline source of truth.
- Now is intentionally live and in-memory. It does not create a saved history
  outside a user-started controlled test.
- Observatory does not provide network, GPU, thermal, or literal
  per-application battery attribution in this release.
