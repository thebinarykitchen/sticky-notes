# swift-accessibility-ids

The single source of truth for the app's accessibility identifiers, exposed as the
`AccessibilityIdentifiers` library.

These identifiers are the contract between the **producers** — SwiftUI views, which
attach them via `.accessibilityIdentifier(_:)` — and the **consumers** — the UI-test
bundle, which locates elements by them. Both sides import this module, so a renamed
identifier is a *compile-time* error rather than a test run that boots a simulator and
only fails halfway through on a stale string.

## Usage

Producer side, in a SwiftUI view:

```swift
import AccessibilityIdentifiers

Button("Add Note", systemImage: "plus") { … }
    .accessibilityIdentifier(A11y.Canvas.addButton)
```

Consumer side, in a UI test:

```swift
import AccessibilityIdentifiers

app.buttons[A11y.Canvas.addButton].tap()
```

## What gets an identifier

Elements a label can't find reliably: the canvas background (no label at all), the notes
(whose text is whatever the reader typed, and may be empty), and app copy like the empty
state and the undo banner. Standard chrome with a fixed label is left out on purpose.

## Notes share one identifier

`A11y.Note.card` is on every note. A test counts notes by it, and tells one from another by
its text or its frame. A per-note identifier would need something a test can know in advance:
a `UUID` isn't, and z-order changes the moment a note is dragged to the front.

## Layout

- `Sources/AccessibilityIdentifiers/A11y.swift` — the registry.
- `Tests/AccessibilityIdentifiersTests/A11yTests.swift` — guards distinctness and prefixes.

Swift 6.4, targets iOS 27 / macOS 27.
