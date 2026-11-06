# AGENTS.md — swift-accessibility-ids

The `A11y` registry: the compile-time contract between SwiftUI views that attach
identifiers and the UI-test bundle that queries them.

Repo-wide conventions: [`../../AGENTS.md`](../../AGENTS.md). Full docs:
[`README.md`](README.md).

## Build & test

```sh
swift test --package-path Packages/swift-accessibility-ids
```

Headless — no simulator, and by far the fastest loop in this repo.

## Rules

- **Never write a raw identifier string** on either side. Add a case to `A11y` and use it
  from both the view and the test — that's the whole point of the package, and it turns a
  rename into a compile error instead of a simulator run that fails halfway.
- **Only identify what a label can't reach.** A fixed "Done" does not earn an identifier.
- Naming: lowercase feature prefix + camelCase leaf, with the Swift namespace mirroring the
  string (`A11y.Canvas.addButton` → `"canvas.addButton"`).
- **Notes are not keyed by z-order.** A drag brings a note to the front, so its index changes
  mid-test. Every note carries `A11y.Note.card`; tell them apart by text or frame.
- No SwiftUI import, no app types. This package is strings and nothing else, which is what
  lets the UI-test bundle and the app both depend on it.

## Traps

- **An identifier on a plain container overwrites the ones inside it.** `VStack`, `ZStack` and
  `ContentUnavailableView` are not accessibility elements, so what is attached to them is pushed
  onto every descendant and replaces what was there. Where a container needs a name and holds
  named children — a note holding its text field — put `.accessibilityElement(children:
  .contain)` on it first.
- **Identifiers on container views are not `otherElements`.** Find `A11y.Note.card` and
  `A11y.Canvas.surface` through `app.descendants(matching: .any).matching(identifier:)`.
- **Context-menu items are UIKit** and drop their identifiers; match "Delete" by label.
