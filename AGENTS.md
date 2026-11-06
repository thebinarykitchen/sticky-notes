# AGENTS.md

StickyNotes — boards of sticky notes for iPhone, iPad and Mac. Each board is its own canvas,
picked from a sidebar (on iPhone, the list behind the canvas). A board has no edges: the canvas
scrolls, and a note held near an edge scrolls it along. Double-tap the canvas to add a note
there, drag a note to move it, pinch it to resize it, tap one to write on it (it comes to the
middle, above the keyboard, and the rest of the board blurs); its menu changes its color. Drag a note
onto the bin, or pinch it until it crumples, to delete it; every delete offers Undo. Where the
device has Apple Intelligence, the toolbar's Make Notes turns what is written in its sheet into
notes with the on-device model: a list into a note per item, a topic into ideas; everywhere else
nothing of it is drawn. A first launch opens on a tour of the gestures, a page each with a board to
try it on; an empty board, the list of boards and the Help menu put it back up. Free has three
boards, ten Make Notes a month and four colors; Sticky Notes Pro, one purchase, lifts the limits
and adds four colors.
`StickyNotes.xcodeproj`, one scheme
over four targets: the app (`StickyNotes/`), the unit tests (`StickyNotesTests/`), the UI
tests (`StickyNotesUITests/`) and the App Store screenshots (`Screenshots/`). Three packages live under `Packages/`: `swift-note-kit` (the model
and store), and `swift-accessibility-ids` and `swift-launch-arguments` (names the app and its UI
tests must agree on). The infrastructure follows [`task-manager`](../task-manager), checked out
beside this one. [`launchpad`](../launchpad), checked out beside it too, takes the screenshots,
and `Screenshots` links its `PreviewRecording`: without that checkout the scheme does not
resolve its packages. The rest of the release tooling is in **Not yet**.

This file is the map and the rules that hold everywhere. Everything else is written down beside
the code it governs; read the one you are about to change.

**Don't guess.** An API, a symbol, a file path, a build setting, a test name: look it up in the
code, the SDK or the docs before you write it. Something that can't be looked up — a decision
nobody has made, a behavior only a run would tell you — is a question or a build, not a
plausible-looking answer. Say what you verified and what you didn't.

| Change | Read first |
| --- | --- |
| An accessibility identifier (`A11y`) | [`Packages/swift-accessibility-ids/AGENTS.md`](Packages/swift-accessibility-ids/AGENTS.md) |
| A launch flag (`LaunchFlag`) | [`Packages/swift-launch-arguments/AGENTS.md`](Packages/swift-launch-arguments/AGENTS.md) |
| The model, the store, the schema, undo | `NoteSchema.swift` and `NoteStore.swift` in [`Packages/swift-note-kit`](Packages/swift-note-kit/Sources/NoteModel) |
| A build or test invocation, the string catalog | [`docs/build.md`](docs/build.md) |
| What Pro covers and what it costs | [`StickyNotes/Pro/AGENTS.md`](StickyNotes/Pro/AGENTS.md) |
| A listing image, the preview video, the functional preview | [`Screenshots/AGENTS.md`](Screenshots/AGENTS.md) |

## Layout

The model is `Packages/swift-note-kit` (`NoteModel`), not a folder here, so it builds and tests
headless in seconds. Under `StickyNotes/`, dependencies only ever run down this list:

- **`NoteModel`** (in the package) — `Board` (which owns its notes, and deletes them with it),
  `Note`, `NoteColor`, the versioned schema, `NoteStore`
  (every write, and every write saves — text once typing pauses), `NoteGeometry` (a note's size
  limits, the clamp that keeps a new note wholly in view, and the rows notes made together
  arrive in), `SampleData`. Knows nothing about views.
- **`Design/`** — the vocabulary the interface is drawn in: `Motion` and `NoteStyle`, and
  `Platform`, the one place a platform is named. No views.
- **`Intelligence/`** — making notes with the on-device model: `NoteWriter` (whether the model
  can run, and the notes it makes of what is written) and `MakeNotesSheet`, which the canvas's
  Make Notes opens. It hands the canvas the notes' texts; the store adds them.
- **`Pro/`** — what is bought and what is left: `Pro` (the App Store, and what is free),
  `ProFeature`, `ProOffer` (the sheet a window shows) and `ProSheet`. Knows the model, `Design/`
  and whether Make Notes can run; the list and the canvas ask it.
- **`Boards/`** — the split view and the list of boards: add, rename, and delete after a
  confirmation. The last board can't be deleted, so there is always a canvas. Searching lists
  every board's notes that match (`SearchResults`, over `Note.search`) in place of the boards;
  picking one opens its board with the note in the middle — a `CanvasView.Reveal`.
- **`Canvas/`** — one board's notes, the note, and its gestures, one per file: `DragToMove` (and its
  `TrashZone`), `Autoscroll` and `PinchToResize` (and its crumple). Also `CanvasScroll` (where the
  canvas is scrolled to, and how much of the board its content covers), `HeldNote`, `EditedNote`,
  `UndoBanner`, and `CanvasOverlays`, which draws those three, the bin and the blur above a
  board's notes — the tour's practice board's too. The board runs under the toolbar and, on iPad,
  under the sidebar: both are insets of the canvas, so whatever it places by its frame — a new
  note, the bin, the undo banner, the note being written on — lands in the part they leave
  uncovered; the keyboard shortens it.
  **A held note is drawn above the scroll view, by `HeldNote`**: in the content it flashes
  whenever the content shifts under it, as the board grows. So is a note being written on, by
  `EditedNote`, whose text field is the only one: every other note draws its words as text, a
  field on each costing launch time and memory. **Every gesture has a non-gesture path** — the
  toolbar's `+` for the double tap, the note's menu and accessibility actions for resize and
  delete, and its Move Up, Down, Left and Right actions, a whole side at a time, for a drag.
- **`Onboarding/`** — the tour: a welcome page and a page per gesture (`Lesson`), each with a
  `PracticeBoard` — the canvas's own notes, gestures and overlays over a throwaway in-memory
  `Practice` store, never the reader's. On it a `Demonstration`, a pure function of time that
  `DemonstrationLayer` draws with the canvas's pieces and a `GhostHand`, loops until the first
  touch; under Reduce Motion it is a still. It takes the board's note only while the note is
  away from rest, so a reader's touch at rest lands on the real one. `OnboardingProgress` says
  when the tour is due — a first launch, or `markDue()` from the empty canvas, the list of boards
  or Help — and `TourStage` keeps it to one window.

## Platforms

iPhone, iPad and Mac out of one app target: `SUPPORTED_PLATFORMS = iphoneos iphonesimulator
macosx`, `TARGETED_DEVICE_FAMILY = 1,2`. Nothing else — a platform claimed is its own
screenshots, its own review pass and a deployment target that has to keep compiling.

- **A platform branch is named once, in `Design/`** — `Platform.swift`. A view does not write
  `#if os(macOS)` itself. **The iPad is a width, not a platform.**
- **Guard the reference, not the branch.** An API that doesn't exist on macOS fails to compile
  even inside a `Bool` that never selects it there; the name itself has to be inside the `#if`.
  The Mac build in [`docs/build.md`](docs/build.md) is the only thing that catches it.
- **The Mac has no UI suite.** `StickyNotesUITests` is iOS-only.

## Stack

- **iOS 27 and macOS 27** minimum. No `if #available` for either.
- **Swift 6** language mode, 6.4 toolchain.
- **SwiftUI** only. Every view gets a `#Preview`; `previewNotes(seeded:)` gives it a store.
- **No Xcode file header comments.** New files start at the first `import`.
- **Comments and docs are concise and precise.** Explain why, not what the code already says.
  `///` only where a name isn't self-explanatory.
- **`@Observable`** for state. Never `ObservableObject` / `@Published` / `@StateObject`.
- **SwiftData** for the notes — `@Query` in views, writes through `NoteStore`. UserDefaults for
  settings only. **The schema is versioned from the first build**: any change to a `@Model` goes
  through a new `VersionedSchema`; the checklist is on `NoteMigrationPlan`. Every stored property
  has a declaration-site default.
- **Animation goes through `Motion`** (`@Environment(\.motion)`), never a literal curve. What a
  finger is holding is not animation: a dragged note tracks it undamped.
- **Undo is the store's own.** Add, move, resize, recolor and delete register their inverse with the
  window's `UndoManager`, which the canvas hands to `NoteStore`; SwiftData's undo is never used,
  and `context.undoManager` stays nil. Undo finds a note by `Note.id`, since one brought back is a
  new instance. Text, stacking order and anything done to a board aren't undoable. **A new stored property has to be taught
  to undo**: `NoteValues` lists what an undone delete puts back, and a test fails until it
  matches the schema. Why, in full: the doc comment on `NoteStore`.
- **A gesture that deletes arms before it commits.** The bin lights up under the finger; a note
  pinched past `NoteGeometry.crumpleSide` crumples. Haptics play on arming, on views that outlive
  the delete — never on the note being deleted, which is gone before the tap lands.
- **UI strings are keys, not literals,** with a translator comment. Text outside a view is a
  `LocalizedStringResource`; a note's own text is the reader's words and never localized.
- **What Pro covers is gated at the call site**, never inside the feature: nothing in
  `NoteModel` or `Intelligence/` knows about Pro. What the reader reaches for stays drawn and
  offers Pro; nothing already made is taken back. See
  [`StickyNotes/Pro/AGENTS.md`](StickyNotes/Pro/AGENTS.md).
- **Apple Intelligence adds, and never replaces.** `FoundationModels` is imported only in
  `NoteWriter.swift`, and nothing of it is drawn unless `NoteWriter.isAvailable`: on a device
  without the model, with Apple Intelligence off, while the model downloads or in a language it
  doesn't speak, the app is the app it always was.

## Concurrency

Default isolation is `@MainActor` (`SWIFT_APPROACHABLE_CONCURRENCY = YES`,
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, and `.defaultIsolation(MainActor.self)` in
`swift-note-kit`) — everywhere but the UI-test bundle, which is `nonisolated` because a subclass
of `XCTestCase` the compiler isolates on its own can't override its initializers; its classes
carry `@MainActor` explicitly.

- Don't add `@MainActor` — it's the default. Annotate the exceptions `nonisolated`.
- `async` alone does not leave the main actor. Offload with `@concurrent nonisolated`.
- From views: `.task` / `.task(id:)`, never `Task {}` in `body` or `init`.
- SwiftData models aren't `Sendable` — pass `PersistentIdentifier` across isolation boundaries.

## Build, format, test

**Every `xcodebuild` writes to `.build/DerivedData`, never Xcode's shared DerivedData** — sharing
it with an open Xcode or a second job fails with "bundle doesn't exist on disk", which reads
exactly like a test failure and is not.

```sh
xcodebuild -project StickyNotes.xcodeproj -scheme StickyNotes \
  -derivedDataPath .build/DerivedData \
  -destination 'platform=iOS Simulator,id=<udid>' -parallel-testing-enabled NO \
  -skip-testing:Screenshots test

swift test --package-path Packages/swift-note-kit       # seconds, headless

swift format --in-place --recursive StickyNotes/ StickyNotesTests/ StickyNotesUITests/ \
  Screenshots/ Packages/
```

The Mac build, the destination-by-id rule, and refilling the string catalog:
[`docs/build.md`](docs/build.md).

Swift Testing (`@Test`, `#expect`), not XCTest; per-test container via
`ModelContainer.inMemory()`. **The UI bundle is the exception** — XCUIAutomation is XCTest-only.

## UI tests

`StickyNotesUITests/` drives the built app through the accessibility tree, and **no raw strings
cross the boundary**: an element is found by `A11y.…` and a launch flag is named by
`LaunchFlag.…`, so a rename is a compile error rather than a simulator run that fails halfway.
The exceptions are labels UIKit owns, like a context menu's "Delete".

- Launch through `AppTestCase.launch(seeded:store:intelligence:)`. It always passes
  `--reduce-motion`, `--ephemeral-store` unless the test is about persistence, and
  `--no-apple-intelligence` unless it is about making notes: whether the model runs in the
  Simulator depends on the Mac. `MakeNotesTests` makes notes through a stand-in instead.
- Every launch but `ProState.whateverStuck` passes `--no-storekit` and presets Pro (locked, with
  nothing spent, unless the test is about Pro): asked what it owns, a simulator answers nothing,
  and the app believes it. Buying is `PurchaseTests`', in the unit tests.
- `underTest` presets the tour answered (`LaunchDefault`) unless the test is about it. A preset
  hides the app's own writes, so a test that needs one to stick relaunches with nothing preset,
  as `TourTests` does. Under Reduce Motion the tour's demonstrations are stills: a loop would
  never let the app idle.
- A test on the real store (`.onDisk`) must find its own notes by unique text and delete them
  when done: the store outlives the run.
- Gestures are `press(forDuration:thenDragTo:…)`, not `swipe…`, which can finish before a
  recognizer measures it.

`Screenshots/` is the second bundle, under the same rule about raw strings. It asserts
nothing: it photographs the listing, records the preview video, and walks the app for the
functional preview. It is in the scheme, so `-only-testing` can reach it, and a full `test`
runs it too unless told `-skip-testing:Screenshots`. See
[`Screenshots/AGENTS.md`](Screenshots/AGENTS.md).

## Not yet

Deliberately out of the first version, and each its own decision when it comes:

- **The rest of the release tooling** — `launchpad.json`'s `preflight` section, which
  `launchpad release` refuses to go without, `PrivacyInfo.xcprivacy` and preflight tests, as in
  `task-manager`.
  `launchpad.json` holds only the `screenshots` and `video-preview` sections so far.
- **A Mac listing.** `Screenshots` is iOS-only, like the UI tests, and the Mac can't be driven
  from a session here; what it would take is in [`Screenshots/AGENTS.md`](Screenshots/AGENTS.md).
- **Zooming.** The canvas scrolls but doesn't zoom; SwiftUI's `ScrollView` has no zoom of its own.
- **iCloud sync.** It would need CloudKit-safe models (the defaults are already there) and an
  iCloud container.

## Gaps

**Scrolling leans on measured, undocumented `ScrollView` behavior** — how `scrollTo(point:)`
reads the insets, and that the opening scroll has to wait a turn; see `CanvasScroll`.
`ScrollTests` checks where notes end up; run it first on a new OS, and `SidebarTests` on an iPad.

**On iPad the board runs under the sidebar because iPadOS 27 runs the board's column under it.**
Nothing here asks for it, and only a look checks that notes show through the sidebar's glass.
Hiding the sidebar moves the board with the sidebar's edge rather than uncovering what was under
it: the scroll view keeps the same board point at the top-left of the uncovered part (seen on
iOS 27).

**A board opens at (0, 0), not where it was left,** unless a search opens it on a note. Nothing
remembers a board's scroll.

**A note is square and at most `NoteGeometry.maxSide`.** At the largest Dynamic Type sizes a
note shows what of its text fits, ending in an ellipsis; written on, the text scrolls inside it.

**Two windows share one undo manager.** The store holds one `undoManager`, set by whichever
canvas last saw its own change, so on an iPad or Mac with two windows open a write can land on
the other window's undo stack. Fixing it means handing the manager to each write.

**A note's accessibility actions are on its card, and VoiceOver focuses the words inside it.**
That the actions are there, and work, is checked in the Simulator; that VoiceOver offers them
from the words isn't, since VoiceOver doesn't run there. Check on a device.

**Activating a note's words with VoiceOver should write on it in the middle,** as a tap does:
the words carry that as their accessibility action. Unchecked, for the same reason; check on a
device.

**A note moved by its Move actions can leave the screen.** The canvas doesn't scroll after it.

**Notes made together land over whatever is in the middle of the screen.** Nothing looks for an
empty spot: made twice without a scroll, a block covers the last one of its size exactly. A block
too tall for the screen runs on below it.

**What the model writes is checked only by `NoteWriterModelTests`,** which run wherever the
model can, a Simulator on this Mac included, and are skipped elsewhere. A Simulator just created
says the model isn't ready, and skips them, for its first few minutes (about four, on iOS 27.0).
How `NoteWriter` asks the model was tuned against them: reworded, it took lists for topics and
refused ordinary lists. Run them after changing it, and on a new OS.

**The Pro sheet and "Sticky Notes Pro…" on a Mac are checked only by compiling.** The sheet's
size, and the menu item in the app menu, want a look on a Mac.

**A refund isn't tested.** `SKTestSession` doesn't take a refund back out of
`currentEntitlements`; `PurchaseTests` checks the same branch with a forged default instead.

**The tour on a Mac is checked only by compiling.** Its sheet's size, the Help menu's item, and a
trackpad pinch on a practice board want a look on a Mac, which has no UI suite.

**A practice board doesn't follow a rotation.** Its notes are laid out for the size the board
first had.

**At the largest text sizes a lesson page's words leave its board little room.** The page can't
scroll — its swipe would fight the board's gestures — so the board takes what is left.

**A second drag may not move a note.** Under `--reduce-motion`, after one note is dragged, no
note moves under a second drag in the same launch, however long after (seen on an iPad
simulator, iOS 27, 2026-10-19). With motion on, two drags of a seeded note both moved it, but
the preview video's journey (add, write, drag, drag) lost its second. Whether the app or
XCUITest's synthesized drag is at fault isn't settled; no UI test drags twice. Reduce Motion is
a reader's setting too, so check by hand on a device. `VideoPreviews` drags once because of it.

**Dragging a note goes the wrong way in a right-to-left layout.** The board mirrors and the
drag's travel doesn't, so the note moves away from the finger (seen with
`-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES`). Nothing right-to-left ships
yet. The Move actions take left and right as seen.
