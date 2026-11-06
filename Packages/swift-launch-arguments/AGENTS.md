# AGENTS.md — swift-launch-arguments

The `LaunchFlag` registry: the compile-time contract between the UI-test bundle that sets a flag
and the app that reads it.

Repo-wide conventions: [`../../AGENTS.md`](../../AGENTS.md). Full docs:
[`README.md`](README.md).

## Build & test

```sh
swift test --package-path Packages/swift-launch-arguments
```

## Rules

- **Never write a raw flag string** on either side. Add a case and use it from both.
- **A stored default a test presets is a `LaunchDefault`**, and the app names its key by the
  same case, so the two can't drift apart. Same bar as a flag: only what a tap can't reach.
- **Only flag what a tap can't reach.** State a test can navigate to is state the test should
  navigate to — a flag that skips the navigation also skips proving it works. The README's table
  says why each existing flag earned its place.
- `isPresent(in:)` takes its arguments as a parameter so the parsing is testable without
  launching a process. Keep it that way.
- No app types, no SwiftUI. Strings and `ProcessInfo`, which is what lets both sides depend on
  it.

## Traps

- **`--seed-store` is `#if DEBUG`**, because every path into `SampleData` is. A Release UI-test
  run gets an empty canvas and every seeded assertion fails at once. Run UI tests against Debug.
- **`--fake-apple-intelligence` is `#if DEBUG` too**, though the stand-in it asks for is in
  every build, for previews. A Release run ignores it and makes notes with the host Mac's
  model, or offers none, so `MakeNotesTests` gets whatever that model writes.
- **`--no-storekit` is `#if DEBUG`**, read in `ProProduct.isOfferedToApp`. A Release UI-test
  run asks the App Store, which answers nothing owned, and every preset Pro state is locked.
- **`--reduce-motion` is folded into `EnvironmentValues.motion`**, not set as an environment
  value: `accessibilityReduceMotion` is read-only. It is OR-ed with the reader's own setting, so
  the flag can only ever turn the setting on.
