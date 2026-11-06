# Build, format, test

The full set, with the traps. The commands you actually reach for are in
[`../AGENTS.md`](../AGENTS.md); this is everything else.

## Derived data is never Xcode's

Every `xcodebuild` below writes to `.build/DerivedData`. A command-line run that shares derived
data with an open Xcode, or with a second job, fails with "bundle doesn't exist on disk" — which
reads exactly like a test failure and is not. Root `.build` is safe because there is no root
`Package.swift`, so SwiftPM never locks it.

**Pass the flag on every invocation, `-showBuildSettings` included:** leave it off one and that
call answers for a different build than the one you made.

## The app

```sh
xcodebuild -project StickyNotes.xcodeproj -scheme StickyNotes \
  -derivedDataPath .build/DerivedData \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

One target at a time — the UI tests boot a simulator and take minutes; the unit tests don't:

```
-only-testing:StickyNotesTests      -only-testing:StickyNotesUITests      -only-testing:Screenshots
```

`Screenshots` is in the scheme only so `-only-testing` can reach it: a skipped testable can't
be, even by name. So a full run takes the listing and the functional preview too, minutes of
them, unless it passes `-skip-testing:Screenshots`.

## Anything that installs the app wants the destination by id

`name=iPhone 17` matches a device on an older runtime just as happily, and the run then sits
there rather than failing. Pick one out of the iOS 27 section of `xcrun simctl list devices
available`. Pass `-parallel-testing-enabled NO` as well: simulator clones fall over often enough
that a parallel failure means nothing.

```sh
xcodebuild -project StickyNotes.xcodeproj -scheme StickyNotes \
  -derivedDataPath .build/DerivedData \
  -destination 'platform=iOS Simulator,id=<udid>' \
  -parallel-testing-enabled NO -skip-testing:Screenshots test
```

## The iPad

`SidebarTests` need an iPad: they turn it to landscape, where the list of boards stands beside the
canvas, and skip wherever nothing does. Run them by id like any UI test:

```sh
xcodebuild -project StickyNotes.xcodeproj -scheme StickyNotes \
  -derivedDataPath .build/DerivedData \
  -destination 'platform=iOS Simulator,id=<iPad udid>' \
  -parallel-testing-enabled NO -only-testing:StickyNotesUITests/SidebarTests test
```

The two accessibility audits fail there, on the sidebar's selected board — the system's white
on the accent, short of iOS 27's contrast — which an iPhone never shows beside the canvas.

The rest of the suite is written for an iPhone in portrait. Turned to landscape it fails in ways
that aren't the app's: `XCUICoordinate.screenPoint` stays in the device's portrait space while
element frames turn with the interface, so a test comparing the two is off by the rotation; and on
an iPad a board's name is both a row in the sidebar and the canvas's title.

## Coverage is off in the scheme

With `codeCoverageEnabled` on, a run that includes `StickyNotesUITests` finishes every test and
then never exits: `xcodebuild` waits on the test operation indefinitely after "All tests passed".
The unit-only run exits normally either way. Until that is understood, the shared scheme gathers
no coverage; pass `-enableCodeCoverage YES` to a unit-only run when you want it.

## The Mac

Nothing else covers it: a compile is the whole check, and an API missing on macOS is what an
iOS-only run cannot see.

```sh
xcodebuild -project StickyNotes.xcodeproj -scheme StickyNotes \
  -derivedDataPath .build/DerivedData \
  -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

## The packages

Headless, and by far the fastest loop here.

```sh
swift test --package-path Packages/swift-accessibility-ids
swift test --package-path Packages/swift-launch-arguments
swift test --package-path Packages/swift-note-kit
```

**Adding a file to a package needs the manifest touched** before Xcode sees it. Xcode caches each
local package's file list, so a new source file compiles under `swift build` and is silently
missing from the app. `touch Packages/swift-note-kit/Package.swift` and build again.

## Refilling the string catalog

Xcode refills `StickyNotes/Localizable.xcstrings` itself. From the command line it is one call
over the app target's `.stringsdata`, **on a build you have just made** — sync writes the
catalog to match what it is given, so a stale directory drops every key it didn't have.

```sh
# Split on ` = `: this checkout's path has a space in it.
DERIVED=$(xcodebuild -project StickyNotes.xcodeproj -scheme StickyNotes \
  -derivedDataPath .build/DerivedData \
  -destination 'platform=iOS Simulator,name=iPhone 17' -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ OBJECT_FILE_DIR_normal =/ {print $2}')
xcrun xcstringstool sync StickyNotes/Localizable.xcstrings \
  --stringsdata "$DERIVED/$(uname -m)"/*.stringsdata
```

A debug build also extracts strings inside `#Preview`s; take any such key out of the catalog by
hand, since it ships.

## Format

```sh
swift format --in-place --recursive StickyNotes/ StickyNotesTests/ StickyNotesUITests/ \
  Screenshots/ Packages/
```

`.swift-format` is the config (4-space indent, 100 columns). Run it before committing; don't
hand-format.
