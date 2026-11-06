# AGENTS.md — Screenshots

The App Store listing, the app preview video, and the functional preview, taken from the app by
a fourth target: a UI-test bundle like `StickyNotesUITests` and for the same reason, but one
that asserts nothing. Each test walks to a screen, waits for it to stop moving, and files the
frame as an attachment. It follows `task-manager`'s `Screenshots/`, beside this checkout.

| Where | What it is for |
| --- | --- |
| `Shot` and `Listing` | The seven listing images, and nine alternates that skip unless asked for. Sells the app. |
| `VideoPreviews` | The app preview video: one recorded journey. |
| `FunctionalPreview.swift` | Every screen and state worth looking at, tiled into an HTML page for review. Sells nothing. |

Same exceptions as `StickyNotesUITests`: XCTest rather than Swift Testing, and nonisolated
default isolation with `@MainActor` on the classes by hand, hence the async `setUp`/`tearDown`.

Repo-wide conventions: [`../AGENTS.md`](../AGENTS.md). The shot list, what each picture
assumes, getting the images out, and the video: [`README.md`](README.md).

## Rules

- **`Shot` is the manifest.** The listing's order and each file name, in one place, so which
  image is which never depends on the order XCTest ran in.
- **`launchpad.json`'s `screenshots` section names `Screenshots/Listing`, never the target.**
  That key decides what `screenshots run` takes and what `app-preview` leaves out. Naming the
  whole target would put every `Preview…` tile into the folder `asc` uploads, where a set holds
  ten. A new listing shot is a test on `Listing`, not a class of its own.
- **A run takes the listing, not the alternates.** A shot past `Shot.lastInTheListing` starts
  with `skipUnlessWanted(_:)` and runs only under `TEST_RUNNER_SCREENSHOT_ALTERNATES=1`.
- **Every shot is taken with Pro unlocked**, but the Pro sheet's: a listing image of a paywall
  sells the price.
- **The shots are of `SampleData.seedListing`** (`--seed-listing`), not the UI tests' seed,
  whose notes are placed for assertions. `Seed` in `Staging` names what the shots look for on
  it; change one, change the other. Its boards are laid out by the canvases they're shot on:
  see the doc comment there.
- **No raw strings across the boundary**, as in the UI tests: `A11y.…` and `LaunchFlag.…`. The
  exceptions are labels UIKit owns — a menu's "Delete", the keyboard tip's "Continue".
- **`Staging` is a deliberate second copy** of the parts of `StickyNotesUITests/App.swift` a
  shot walks past, since two test bundles link no code in common. Keep it thin.
- **Anything that types puts the keyboard tip away first** (`dismissTheKeyboardTip()`). A
  simulator's first keyboard comes with one, which takes the typing and would be in the shot.
- **The functional preview stands on its own.** It is every class here but `Listing` and
  `VideoPreviews`, so it takes the listing's screens again rather than borrowing them.
  `PreviewShots` numbers tiles from 100, a block of ten per section. The `Preview` class prefix
  is load bearing: `app-preview` reads its progress line off `Preview<Something>/test…`. Its
  rule for a missing thing is the opposite of a listing shot's: what depends on the device
  skips rather than fails.
- **`VideoPreviews` runs with motion on**, and is the class the `video-preview` section names.
  Its last beat, `notes-made`, is the poster frame (`posterBeat`); rename one, rename both.
- **iOS only, for now.** The target is `SDKROOT = iphoneos`, like the UI tests, and
  `launchpad.json` lists only `ios`. A Mac listing means `#if os(macOS)` paths here — the
  window, not `XCUIScreen`; `click()`, not `tap()` — and a `macos` platform in both sections.

## Taking them

```sh
# The listing on both devices the screenshots section names, into .appstore/<version>/screenshots
swift run --package-path ../launchpad/Packages/swift-app-store screenshots run

swift run --package-path ../launchpad/Packages/swift-app-store video-preview run

# Every class but Listing and VideoPreviews, into .appstore/functional-preview/index.html
swift run --package-path ../launchpad/Packages/swift-app-store app-preview
```

A plain `xcodebuild test` runs this target too, since the scheme has to list it for
`-only-testing` to reach it: pass `-skip-testing:Screenshots` to leave it out.
