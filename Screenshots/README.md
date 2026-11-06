# Screenshots

The App Store listing, taken from the app rather than drawn over it. A fourth target, a UI-test
bundle like `StickyNotesUITests` and for the same reason: driving the built app through the
accessibility tree is the only way to photograph it in a state it actually reaches.

Nothing here asserts anything about the app. `StickyNotesUITests` is where behavior is checked;
this walks to a screen, waits for it to stop moving, and files the frame.

## The shot list

`Shot` is the manifest: the number is the order the listing shows them in, and it is part of
the file name. Every shot is a test on `Listing`, the one class `launchpad.json`'s `screenshots`
section names.

**One to seven are the listing**, ordered the way the question is asked: what is this, then
what does it do, then everything else.

| # | Shot | What it shows | Taken by |
| --- | --- | --- | --- |
| 01 | `the-board` | "Home", a board full of notes in every color. The image beside the search result, so the only one most people see. | `testTheBoard` |
| 02 | `writing-on-a-note` | A note tapped: in the middle, above the keyboard, the board blurred behind it. | `testWritingOnANote` |
| 03 | `making-notes` | Make Notes' sheet with a list written in, over the empty "Groceries". | `testMakingNotes` |
| 04 | `notes-made` | The list as a note per item, together in the middle of the board. | `testNotesMade` |
| 05 | `a-notes-colors` | A note held: its menu, every color, the non-gesture resize and delete. | `testANotesColors` |
| 06 | `every-board` | The list of boards, back from the canvas on a phone. On a 13-inch iPad the list is already beside the canvas in 01, so this is the list beside another full board, "Lisbon". | `testEveryBoard` |
| 07 | `search` | One search over every board, each note found under the board it is on. | `testSearch` |

**Eight up are alternates.** They skip unless the run asks for them with
`TEST_RUNNER_SCREENSHOT_ALTERNATES=1`: `screenshots run` files every image it gets into the
device's folder, and `asc` uploads the whole folder.

| # | Shot | Why keep it |
| --- | --- | --- |
| 08–15 | `tour-welcome`, then one per lesson page | The tour's pages, each with its practice board and the demonstration's still. Out of the listing: a tour page reads as a tutorial. |
| 16 | `unlocking-pro` | The offer itself, with its real price: the picture App Store Connect wants of the in-app purchase. |

### Make Notes is the stand-in, not the model

03 and 04 launch with `--fake-apple-intelligence`, the Debug stand-in the UI tests make notes
with: a note per line or comma-separated item. The sheet, the button and the way the notes
arrive are the app's own; only what turns the words into notes is staged. For a list, which is
what the shot writes, the model does the same thing, and its words would vary from run to run.
Nor would the model run everywhere: a simulator just created says it isn't ready for its first
few minutes. A topic turned into ideas, the other half of the feature, isn't photographed.

### The gestures are not in the stills

A drag, a pinch and the bin are a direction and a distance, and a still of the board after one
is just the board. XCUITest can't take a screenshot while a drag is held, so the bin lit under a
note can't be photographed. The video carries the gestures instead, and the tour's pages
(alternates 09–15) name them.

## The listing's boards

Every shot is of `SampleData.seedListing`, through `--seed-listing`, not the UI tests'
`--seed-store`, whose notes are placed for assertions. Four boards:

- **"Home"**, which a launch opens, with every color on it, Pro's included.
- **"Lisbon"**, as full, for 06 on an iPad.
- **"Work"**, a few notes, for the list and the search.
- **"Groceries"**, empty, for Make Notes to fill.

Home and Lisbon are laid out by what the two devices show of them. A board opens with its
(0, 0) at the canvas's top-left, so the top-left 440 × 800 points are the whole of the phone's
picture. Up to 700 × 1300 is the iPad's: a 13-inch iPad keeps the list of boards beside the
canvas even in portrait, and it takes about 330 of the 1032 points. A note moved in the seed
moves in both pictures, so look at both.

`Seed` in `Staging` names what the shots look for on these boards, down to a board point no note
covers for the video's double tap. Change the seed and check it.

## Taking them

```sh
swift run --package-path ../launchpad/Packages/swift-app-store screenshots run
```

That builds once, runs `Screenshots/Listing` on both devices the `screenshots` section names,
cleans the status bar, and writes `.appstore/<version>/screenshots/<device>/` and a contact sheet.

By hand, one device at a time (parallel `xcodebuild` jobs share DerivedData and fail each other):

```sh
UDID=<iPhone 17 Pro Max, or iPad Pro 13-inch (M5), from the iOS 27 section, by id>
xcrun simctl boot "$UDID"; xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3

xcodebuild -project StickyNotes.xcodeproj -scheme StickyNotes \
  -derivedDataPath .build/DerivedData \
  -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:Screenshots/Listing -parallel-testing-enabled NO \
  -collect-test-diagnostics never -resultBundlePath shots.xcresult test
```

`TEST_RUNNER_SCREENSHOT_ALTERNATES=1` in front takes the alternates too; keep them out of the
listing's folder. `xcrun simctl ui "$UDID" appearance dark` before the run takes them dark.

## Getting the images out

They are attachments. `xcresulttool` exports them under UUIDs, with a manifest naming each:

```sh
xcrun xcresulttool export attachments --path shots.xcresult --output-path raw
python3 - <<'PY'
import json, os, re, shutil
os.makedirs("listing", exist_ok=True)
for test in json.load(open("raw/manifest.json")):
    for a in test["attachments"]:
        shot = re.match(r"^(\d\d-[a-z0-9-]+)_\d+_[0-9A-F-]+\.png$", a["suggestedHumanReadableName"])
        if shot:
            shutil.copyfile(f"raw/{a['exportedFileName']}", f"listing/{shot.group(1)}.png")
PY
```

## What the pictures assume

- **A Debug build.** `--seed-listing`, `--fake-apple-intelligence` and `--no-storekit` are all
  `#if DEBUG`: a Release run photographs an empty board seven times.
- **`--reduce-motion`,** for the shutter: a note still settling photographs in the wrong place.
- **Pro unlocked, with `--no-storekit`,** but for 16, which is launched locked and asks the
  scheme's `StoreKit.storekit` for its price. Without that, the sheet offers Try Again and the
  shot fails rather than file it.
- **A simulator that shows the software keyboard.** 02, 03 and 07 have it up. Whether one does
  is remembered per device: one that has seen a hardware keyboard may never show it, under
  XCUITest too, and the shots then come out without it. A device just created shows it, and its
  first keyboard brings a "slide to type" tip, which `dismissTheKeyboardTip()` puts away.

## The functional preview

The listing is the app at its best. The functional preview is the other question — *what does
all of it actually look like* — and it is every class in this target but `Listing` and
`VideoPreviews`, which `app-preview` always leaves out:

```sh
swift run --package-path ../launchpad/Packages/swift-app-store app-preview
swift run --package-path ../launchpad/Packages/swift-app-store app-preview \
  --appearance light --appearance dark      # each device twice, a tab per pass
```

It writes `.appstore/functional-preview/index.html`. The tiles are numbered from 100 up, a block
of ten per section, and `app-preview` renumbers them 01…N.

| From | What it shows |
| --- | --- |
| `PreviewFirstRun` | The empty first board, and the tour: its welcome, each lesson page, and the board it leaves. |
| `PreviewTheBoard` | The board, a note added from the toolbar being written on, a note's menu, the offer to undo a delete, and a note at its largest. |
| `PreviewBoards` | The list of boards and its prompts: naming a new board, a board's menu, renaming, deleting. Then the list beside the canvas in landscape, which skips where nothing stands beside it. |
| `PreviewSearch` | Hits on every board, no hits, and a note picked: its board, the note in the middle. |
| `PreviewMakeNotes` | The sheet empty, written in, and the notes it made. |
| `PreviewPro` | The sheet and a restore. Then the three walls: a fourth board, a Pro color, Make Notes spent. |
| `PreviewLargestType` | The board, a note being written on, and the list, at `AccessibilityXXXL`. |

The walls run with `--no-storekit`, so they offer Try Again where the price goes: the wall is
the subject, not the price. The sheet's own tile asks StoreKit. `app-preview` runs from an
`.xctestrun`, which may not carry the scheme's StoreKit configuration; where nothing answers,
the restore tile skips.

## The preview video

One recorded run through the app. `VideoPreviews` is the class the `video-preview` section names:

```sh
swift run --package-path ../launchpad/Packages/swift-app-store video-preview run
```

The tool records each simulator between the markers the test writes through `PreviewRecorder`
(launchpad's `swift-preview-recording`, which the target links from `../launchpad`). It keeps
four seconds from each beat and drops the idle stretch between them.

| Beat | What is on screen |
| --- | --- |
| `writing-one-down` | A double tap on a free spot of "Home": a note comes to the middle and is written on. |
| `into-the-bin` | The note dragged across the board onto the bin, and Undo bringing it back. |
| `making-it-bigger` | The note pinched apart. |
| `its-color` | Its menu held open, and a color only Pro has picked. |
| `making-notes` | "Groceries", and a list written into Make Notes. |
| `notes-made` | The list arriving as a note per item. The poster frame. |

**It drags once.** On iOS 27 a second drag in one launch never moved a note: any note, after
any drag, under `--reduce-motion` (seen on the iPad); and on this journey, after a note was
written on and dragged, with motion on too. That is the app's or XCUITest's, not settled — see
the root AGENTS.md's Gaps. So the move and the bin are one beat.

It runs with motion on, unlike the stills: a recording of a board that never moves is a
recording of a screenshot. It makes notes with the stand-in, as 03 and 04 do. Before the
recorder starts, it brings the keyboard up once, so a fresh simulator's tip isn't on camera.
One journey serves both sizes. `openBoard(_:)` goes back to the list on a phone and uses the
list beside the canvas on an iPad.
