import CoreGraphics
import Foundation
import SwiftData
import Testing
import os

@testable import NoteModel

struct NoteStoreTests {
    let container: ModelContainer
    let store: NoteStore
    let visible = CGRect(x: 0, y: 0, width: 400, height: 800)
    let board: Board

    init() throws {
        container = try .inMemory()
        store = NoteStore(context: container.mainContext)
        board = store.addBoard(named: "Board")
    }

    private func notes() throws -> [Note] {
        try container.mainContext.fetch(FetchDescriptor<Note>(sortBy: [SortDescriptor(\.z)]))
    }

    /// What has been saved, read through a context of its own: the store's own context also
    /// returns what it hasn't saved.
    private func saved() throws -> [Note] {
        try ModelContext(container).fetch(FetchDescriptor<Note>(sortBy: [SortDescriptor(\.z)]))
    }

    /// How many times `writes` saves the store.
    private func saves(_ writes: () -> Void) -> Int {
        let saves = OSAllocatedUnfairLock(initialState: 0)
        let observer = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: container.mainContext, queue: nil
        ) { _ in saves.withLock { $0 += 1 } }
        defer { NotificationCenter.default.removeObserver(observer) }
        writes()
        return saves.withLock { $0 }
    }

    @Test func addPlacesANoteWhereItWasAsked() throws {
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        #expect(note.center == CGPoint(x: 200, y: 300))
        #expect(note.text.isEmpty)
        #expect(try notes().count == 1)
    }

    @Test func eachNewNoteGoesOnTop() {
        let first = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        let second = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        #expect(second.z > first.z)
    }

    @Test func colorsRotateFromTheNewestNote() {
        let colors = (0..<5).map { _ in
            store.add(at: .init(x: 200, y: 300), within: visible, on: board).color
        }
        #expect(colors == [.yellow, .pink, .blue, .green, .yellow])
    }

    /// A color that is only ever chosen isn't handed on: the next note starts the rotation again.
    @Test func aChosenColorIsntHandedOn() {
        let top = store.add(at: .init(x: 200, y: 300), within: visible, on: board)
        store.recolor(top, to: .purple)
        let next = store.add(at: .init(x: 200, y: 300), within: visible, on: board)
        #expect(next.color == .yellow)
        let several = store.add(["One", "Two"], within: visible, on: board)
        #expect(several.map(\.color) == [.pink, .blue])
    }

    @Test func everyColorIsEitherHandedOutOrChosen() {
        #expect(Set(NoteColor.handedOut).isSubset(of: NoteColor.allCases))
        #expect(Set(NoteColor.handedOut).count == NoteColor.handedOut.count)
        for color in NoteColor.allCases {
            #expect(NoteColor.handedOut.contains(color.next))
        }
    }

    @Test func addAtTheEdgeKeepsTheWholeNoteInView() {
        let note = store.add(at: CGPoint(x: 0, y: 900), within: visible, on: board)
        let half = NoteGeometry.defaultSide / 2
        #expect(note.center == CGPoint(x: half, y: visible.maxY - half))
    }

    /// What is on screen is anywhere on the board once the canvas has scrolled.
    @Test func addKeepsTheNoteInViewWhereverTheCanvasIsScrolled() {
        let scrolled = CGRect(x: -1_000, y: 2_000, width: 400, height: 800)
        let note = store.add(at: CGPoint(x: -1_100, y: 3_000), within: scrolled, on: board)
        let half = NoteGeometry.defaultSide / 2
        #expect(note.center == CGPoint(x: scrolled.minX + half, y: scrolled.maxY - half))
    }

    /// A board has no edges.
    @Test func aNoteMovesWhereverItIsPut() {
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        store.move(note, to: CGPoint(x: 5_000, y: -1_200))
        #expect(note.center == CGPoint(x: 5_000, y: -1_200))
    }

    @Test func aNewNoteIsTheDefaultSize() {
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        #expect(note.side == NoteGeometry.defaultSide)
    }

    @Test func resizeIsHeldToTheLimits() {
        let note = store.add(at: CGPoint(x: 200, y: 400), within: visible, on: board)
        store.resize(note, to: 10_000)
        #expect(note.side == NoteGeometry.maxSide)
        store.resize(note, to: 1)
        #expect(note.side == NoteGeometry.minSide)
    }

    /// Even at the edge of the screen: the canvas scrolls to whatever grows past it.
    @Test func aNoteGrowsAboutItsCentre() {
        let note = store.add(at: CGPoint(x: 0, y: 0), within: visible, on: board)
        let center = note.center
        store.resize(note, to: NoteGeometry.maxSide)
        #expect(note.center == center)
    }

    @Test func recolorChangesOnlyTheColor() throws {
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        let placement = Placement(of: note)
        store.recolor(note, to: .blue)
        #expect(try saved().first?.color == .blue)
        #expect(Placement(of: note) == placement)
    }

    /// A color this build doesn't know reads as yellow, but isn't: made yellow, it is written.
    @Test func aNoteOfAnUnknownColorCanBeMadeYellow() throws {
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        note.colorRaw = "mauve"
        store.recolor(note, to: .yellow)
        #expect(try saved().first?.colorRaw == NoteColor.yellow.rawValue)
    }

    @Test func aDropRaisesOnlyWhatIsBelow() {
        let bottom = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        let top = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        let topZ = top.z

        store.drop(top, at: top.center)
        #expect(top.z == topZ)

        store.drop(bottom, at: bottom.center)
        #expect(bottom.z > top.z)
    }

    /// Raised and moved in one save: each save re-renders every note on the board.
    @Test func aDropSavesOnce() {
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)

        #expect(saves { store.drop(note, at: CGPoint(x: 100, y: 500)) } == 1)
    }

    @Test func severalNotesArriveInReadingOrderSayingTheirTexts() throws {
        let notes = store.add(["Milk", "Eggs", "Bread"], within: visible, on: board)
        #expect(notes.map(\.text) == ["Milk", "Eggs", "Bread"])
        #expect(
            notes.map(\.center)
                == NoteGeometry.rows(of: 3, side: NoteGeometry.defaultSide, in: visible))
        #expect(try saved().map(\.text) == ["Milk", "Eggs", "Bread"])
    }

    @Test func severalNotesGoOnTopAndCarryOnTheColors() {
        let first = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        let notes = store.add(["Milk", "Eggs", "Bread", "Tea"], within: visible, on: board)
        #expect(notes.map(\.z) == [first.z + 1, first.z + 2, first.z + 3, first.z + 4])
        #expect(notes.map(\.color) == [.pink, .blue, .green, .yellow])
    }

    /// Each save re-renders every note on the board.
    @Test func severalNotesAreAddedInOneSave() {
        #expect(saves { store.add(["Milk", "Eggs", "Bread"], within: visible, on: board) } == 1)
    }

    @Test func noTextsAddNothingAndSaveNothing() throws {
        var added: [Note] = []
        #expect(saves { added = store.add([], within: visible, on: board) } == 0)
        #expect(added.isEmpty)
        #expect(try notes().isEmpty)
    }

    /// Put down where it was picked up, a note is still raised, and that is saved.
    @Test func aDropInPlaceSavesTheRaise() throws {
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)

        store.drop(note, at: note.center)
        #expect(try saved().last?.id == note.id)
    }

    /// Typing reads back at once, but reaches the note, and is saved, only once it pauses: any
    /// change to a note has every query over notes fetch again.
    @Test func textSavesWhenTypingPauses() async throws {
        store.textSaveDelay = .milliseconds(50)
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)

        store.setText("Mi", of: note)
        store.setText("Milk", of: note)
        #expect(store.text(of: note) == "Milk")
        #expect(note.text.isEmpty)
        #expect(!container.mainContext.hasChanges)

        let deadline = ContinuousClock.now + .seconds(5)
        while note.text.isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(try saved().first?.text == "Milk")
    }

    /// Typing into another note puts what the first was waiting on into it.
    @Test func typingIntoAnotherNoteWritesTheFirst() throws {
        let first = store.add(at: CGPoint(x: 100, y: 300), within: visible, on: board)
        let second = store.add(at: CGPoint(x: 300, y: 300), within: visible, on: board)

        store.setText("Milk", of: first)
        store.setText("Eggs", of: second)
        #expect(first.text == "Milk")
        #expect(store.text(of: second) == "Eggs")

        store.saveText()
        #expect(try saved().map(\.text) == ["Milk", "Eggs"])
    }

    @Test func saveTextSavesAtOnce() throws {
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        store.setText("Milk", of: note)
        store.saveText()
        #expect(try saved().first?.text == "Milk")
    }

    /// Any other write saves typing that hasn't paused yet.
    @Test func anotherWriteSavesTextStillWaiting() throws {
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        store.setText("Milk", of: note)
        store.move(note, to: CGPoint(x: 100, y: 500))
        #expect(try saved().first?.text == "Milk")
    }

    @Test func deleteRemovesTheNote() throws {
        let keep = store.add(at: CGPoint(x: 100, y: 300), within: visible, on: board)
        let gone = store.add(at: CGPoint(x: 300, y: 300), within: visible, on: board)
        store.delete(gone)
        #expect(try notes().map(\.id) == [keep.id])
    }
}

struct NoteSearchTests {
    let container: ModelContainer
    let store: NoteStore
    let visible = CGRect(x: 0, y: 0, width: 400, height: 800)

    init() throws {
        container = try .inMemory()
        store = NoteStore(context: container.mainContext)
    }

    private func found(_ query: String) throws -> [String] {
        try container.mainContext.fetch(Note.search(query)).map(\.text)
    }

    private func add(_ text: String, at point: CGPoint, on board: Board) {
        let note = store.add(at: point, within: visible, on: board)
        store.setText(text, of: note)
        store.saveText()
    }

    /// Case and accents aside, as a reader types.
    @Test func searchIgnoresCaseAndAccents() throws {
        let board = store.addBoard(named: "Home")
        add("Café au lait", at: CGPoint(x: 100, y: 100), on: board)
        add("Buy oat milk", at: CGPoint(x: 100, y: 300), on: board)

        #expect(try found("CAFE") == ["Café au lait"])
        #expect(try found("milk") == ["Buy oat milk"])
        #expect(try found("tea").isEmpty)
    }

    @Test func searchReachesEveryBoard() throws {
        let home = store.addBoard(named: "Home")
        let work = store.addBoard(named: "Work")
        add("Book the team offsite", at: CGPoint(x: 100, y: 100), on: work)
        add("Book a haircut", at: CGPoint(x: 100, y: 300), on: home)

        let notes = try container.mainContext.fetch(Note.search("book"))
        #expect(Set(notes.compactMap(\.board?.name)) == ["Home", "Work"])
    }

    /// The order a board is read in, whatever order the notes were added in.
    @Test func resultsRunTopToBottomThenLeftToRight() throws {
        let board = store.addBoard(named: "Home")
        add("Note low", at: CGPoint(x: 100, y: 500), on: board)
        add("Note right", at: CGPoint(x: 300, y: 100), on: board)
        add("Note left", at: CGPoint(x: 100, y: 100), on: board)

        #expect(try found("note") == ["Note left", "Note right", "Note low"])
    }
}

struct NoteGeometryTests {
    @Test func aCanvasNarrowerThanANoteCentresIt() {
        let side = NoteGeometry.defaultSide
        let point = NoteGeometry.clamp(
            CGPoint(x: 10, y: 10), side: side, in: CGRect(x: 0, y: 0, width: 100, height: 400))
        #expect(point == CGPoint(x: 50, y: side / 2))
    }

    @Test func aPointAlreadyInsideIsUntouched() {
        let point = CGPoint(x: 200, y: 200)
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 400)
        #expect(NoteGeometry.clamp(point, side: NoteGeometry.defaultSide, in: bounds) == point)
    }

    @Test func boundsAwayFromTheOriginClampToThemselves() {
        let bounds = CGRect(x: -900, y: 1_500, width: 400, height: 400)
        let half = NoteGeometry.defaultSide / 2
        let point = NoteGeometry.clamp(.zero, side: NoteGeometry.defaultSide, in: bounds)
        #expect(point == CGPoint(x: bounds.maxX - half, y: bounds.minY + half))
    }

    @Test func sideIsHeldBetweenTheLimits() {
        #expect(NoteGeometry.clampSide(0) == NoteGeometry.minSide)
        #expect(NoteGeometry.clampSide(10_000) == NoteGeometry.maxSide)
        #expect(NoteGeometry.clampSide(200) == 200)
    }
}

/// Notes that arrive together, on an iPhone's canvas unless a test needs more room.
struct NoteRowsTests {
    let side = NoteGeometry.defaultSide
    /// From one note's centre to the next one's.
    let pitch = NoteGeometry.defaultSide + NoteGeometry.gap
    let phone = CGRect(x: 0, y: 0, width: 400, height: 800)

    @Test func oneNoteGoesInTheMiddle() {
        #expect(NoteGeometry.rows(of: 1, side: side, in: phone) == [CGPoint(x: 200, y: 400)])
    }

    @Test func fourNotesMakeASquareInTheMiddle() {
        let near = 200 - pitch / 2
        let far = 200 + pitch / 2
        #expect(
            NoteGeometry.rows(of: 4, side: side, in: phone) == [
                CGPoint(x: near, y: 400 - pitch / 2), CGPoint(x: far, y: 400 - pitch / 2),
                CGPoint(x: near, y: 400 + pitch / 2), CGPoint(x: far, y: 400 + pitch / 2),
            ])
    }

    /// Left to right, then down: a short last row starts at the left.
    @Test func fiveNotesMakeRowsOfThreeAndTwo() {
        let wide = CGRect(x: 0, y: 0, width: 1_000, height: 800)
        let top = 400 - pitch / 2
        let bottom = 400 + pitch / 2
        #expect(
            NoteGeometry.rows(of: 5, side: side, in: wide) == [
                CGPoint(x: 500 - pitch, y: top), CGPoint(x: 500, y: top),
                CGPoint(x: 500 + pitch, y: top),
                CGPoint(x: 500 - pitch, y: bottom), CGPoint(x: 500, y: bottom),
            ])
    }

    @Test func neighboursAreASideAndAGapApart() {
        let centers = NoteGeometry.rows(of: 4, side: side, in: phone)
        #expect(centers[1] == CGPoint(x: centers[0].x + pitch, y: centers[0].y))
        #expect(centers[2] == CGPoint(x: centers[0].x, y: centers[0].y + pitch))
    }

    /// The first notes are on screen; the rest reach below it.
    @Test func aBlockTooTallStartsAGapBelowTheTop() {
        let short = CGRect(x: 0, y: 1_000, width: 400, height: 300)
        let first = NoteGeometry.rows(of: 4, side: side, in: short).first
        #expect(first == CGPoint(x: 200 - pitch / 2, y: short.minY + NoteGeometry.gap + side / 2))
    }

    @Test func boundsNarrowerThanANoteMakeOneCentredColumn() {
        let narrow = CGRect(x: 0, y: 0, width: 100, height: 800)
        #expect(
            NoteGeometry.rows(of: 3, side: side, in: narrow) == [
                CGPoint(x: 50, y: 400 - pitch), CGPoint(x: 50, y: 400),
                CGPoint(x: 50, y: 400 + pitch),
            ])
    }

    @Test func noNotesHaveNoPlace() {
        #expect(NoteGeometry.rows(of: 0, side: side, in: phone).isEmpty)
    }
}

struct NoteSchemaTests {
    @Test func currentSchemaIsTheNewestInThePlan() {
        let last = NoteMigrationPlan.schemas.last
        #expect(last.map(ObjectIdentifier.init) == ObjectIdentifier(CurrentSchema.self))
    }

    @Test func anUnknownColorReadsAsYellow() {
        let note = Note(center: .zero, color: .blue, z: 0)
        note.colorRaw = "mauve"
        #expect(note.color == .yellow)
    }
}

struct CrumpleTests {
    @Test func onlyAPinchPastTheThresholdCrumples() {
        #expect(NoteGeometry.crumples(NoteGeometry.crumpleSide - 1))
        #expect(!NoteGeometry.crumples(NoteGeometry.crumpleSide))
        #expect(!NoteGeometry.crumples(NoteGeometry.minSide))
        #expect(NoteGeometry.crumpleSide < NoteGeometry.minSide)
    }
}
