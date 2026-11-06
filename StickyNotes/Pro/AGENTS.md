# AGENTS.md — Pro

What is bought and what is left: the App Store, the one non-consumable (`ProProduct.id`, $3.99,
Family Sharing, no subscription), and what is free of each thing it covers. Copied from
`task-manager`'s `Pro/`, and kept close to it. Repo-wide conventions: [`../../AGENTS.md`](../../AGENTS.md).

## What is free

`ProFeature.swift` has the three and their sheet copy:

- **Make Notes** — `freeMakeNotes` runs a calendar month, back on the 1st. Spent when a run's
  notes arrive, so a cancelled or failed one costs nothing.
- **Boards** — `freeBoards` at once. Counted as they stand, never spent: deleting one frees its
  place.
- **Colors** — `NoteColor.handedOut` are free, and new notes only ever get those; the other
  four are Pro only.

The numbers are spelled out in the copy too; `ProTests` fails when the two disagree.

## Gated at the call site, never inside the feature

`Pro.allows(_:)`, `allowsAnotherBoard(having:)` and `allows(_:)` with a color on the way in;
`Pro.spend(_:)` on the way past. `NoteModel` and `Intelligence/` know nothing about Pro: the store
recolors whatever it is told to, and `NoteWriter` runs whenever it is asked.

What the reader reaches for **stays drawn** and offers Pro when nothing is left — New Board, Make
Notes, a Pro color in a note's menu. A button that vanished is a button nobody can be told
anything by. The run that spends the last free Make Notes offers Pro as its notes land.

**Nothing is taken back.** After a refund every board and every colored note stays; only adding
another board, or choosing a Pro color again, asks.

**Make Notes is sold only where it runs.** The sheet leaves its card out unless
`NoteWriter.isAvailable` — Apple Intelligence adds, and never replaces.

## The sheet is per window

`ProOffer` is the sheet a window shows and why; `BoardsView` owns one and presents `ProSheet`
from it, and hands it down as `\.proOffer` and to the menu bar as a focused value
(`ProCommands`). The tour's practice board has none, so its notes take every color.

A color picked while locked is **tried, not written**: the sheet shows it on the note, and only
a purchase made there writes it.

## The App Store is the truth

`pro.unlocked` is a cache. `Pro.refresh()` believes the store in both directions, so a preset
default is not a way in — which is why the UI tests pass `--no-storekit` alongside a preset Pro
state. That flag is `#if DEBUG`: a launch argument is an `open --args` away on a Mac.

What a purchase does is `StickyNotesTests/PurchaseTests.swift`, against `SKTestSession` and
the root `StoreKit.storekit`, which is bundled into the unit tests and set on the scheme's Run
and Test actions.

## The purchase starts in the view

`Pro.buy(with:)` takes the sheet's `@Environment(\.purchase)`, which knows the sheet's window,
so the payment sheet opens over the one that asked. `PurchaseTests` go through `buy(_:)`,
answering for the App Store themselves. `ProductView` and `StoreView` are not used: they load
the product themselves, which `--no-storekit` can't stop.
