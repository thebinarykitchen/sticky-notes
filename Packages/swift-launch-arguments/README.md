# swift-launch-arguments

The single source of truth for the app's launch-argument flags, exposed as the
`LaunchArguments` library.

These flags are the contract between the **producer** — the `StickyNotesUITests` and
`Screenshots` bundles, which set them via `XCUIApplication.launchArguments` — and the **consumer** — the app,
which reads them out of the running process. Both sides import this module, so a renamed
flag is a *compile-time* error rather than a silent no-op where one side sets a string the
other never looks for.

## What earns a flag

Only state a test cannot reach any other way. Everything a tap can reach, a test reaches by
tapping — a test that adds its own note by double-tapping also proves double-tapping works.

| Flag | Why it can't be tapped |
| --- | --- |
| `--ephemeral-store` | The real store is on disk. Without this each test inherits the last one's notes and the run depends on the order they went in. |
| `--seed-store` | Several notes to act on without adding each first. Debug builds only, like every path into `SampleData`. |
| `--seed-listing` | The boards the App Store listing photographs, in place of `--seed-store`'s: some thirty notes laid out by the canvases they are shot on, which no test should be adding by hand. Debug builds only. |
| `--reduce-motion` | The app settles sooner: adds and deletes don't animate, so a test isn't waiting for idle. |
| `--no-apple-intelligence` | Whether the on-device model runs in the Simulator depends on the Mac hosting it, and no tap turns it off. Without it, a test's toolbar would differ from Mac to Mac. |
| `--fake-apple-intelligence` | The model's notes vary from run to run, and it runs only where the host Mac has it. The stand-in makes a note of each line or comma-separated item, so a test knows what it gets. Debug builds only. |
| `--no-storekit` | A simulator asked what it owns answers nothing, and the app believes the store over its own cache — so without it a preset `pro.unlocked` is locked straight back. Debug builds only: on a Mac a launch argument is an `open --args` away. |

## Presetting a default

`LaunchDefault` names a `UserDefaults` key the app keeps, for a test to preset with
`arguments(_:)`: `-key value` lands in the argument domain, which wins over whatever is stored.
What the app writes still persists, but isn't read back while the argument is there — so a test
that checks a write sticks relaunches without it.

| Key | Why it can't be tapped |
| --- | --- |
| `onboarding.finished` | Whether the tour is up at launch depends on what the last run on that simulator left in its defaults, which `--ephemeral-store` doesn't reach. Answered by tapping, it would put the tour at the top of every test. The UI tests preset it answered, unless a test is about the tour. |
| `pro.unlocked` | Buying Pro is a payment sheet no test can get through. Holds only with `--no-storekit`. |
| `pro.used.makeNotes` | Running out takes ten Make Notes runs, and the count outlives the ephemeral store. The UI tests preset it, to none spent unless a test is about running out. |

## Usage

Producer side, in a UI test:

```swift
import LaunchArguments

app.launchArguments = [LaunchFlag.ephemeralStore.rawValue, LaunchFlag.seedStore.rawValue]
app.launch()
```

Consumer side, in the app:

```swift
import LaunchArguments

if LaunchFlag.ephemeralStore.isPresent() { … }
```

`isPresent(in:)` takes the arguments to inspect, defaulting to the current process, which is
what lets the parsing be tested without launching anything.

## Layout

- `Sources/LaunchArguments/LaunchArguments.swift` — `LaunchFlag` and `LaunchDefault`.
- `Tests/LaunchArgumentsTests/LaunchArgumentsTests.swift` — guards the spellings.

Swift 6.4, targets iOS 27 / macOS 27.
