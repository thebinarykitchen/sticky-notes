import AccessibilityIdentifiers
import CoreGraphics
import Foundation
import NoteModel
import Testing

@testable import StickyNotes

@Suite("The tour's pages")
struct TourPageTests {
    @Test("The welcome page, then a page per lesson, in teaching order")
    func pagesAreInOrder() {
        #expect(TourPage.all.first == .welcome)
        #expect(TourPage.all.compactMap(\.lesson) == Lesson.allCases)
        #expect(TourPage.all.count == Lesson.allCases.count + 1)
    }

    @Test("Pressing on visits every page once, and then ends")
    func pressingOnVisitsEveryPage() {
        var page = TourPage.welcome
        var visited = [page]
        while let next = page.next, visited.count <= TourPage.all.count {
            page = next
            visited.append(page)
        }
        #expect(visited == TourPage.all)
    }

    @Test("Start, then Next, then Get Started")
    func theWayOnSaysWhereItGoes() {
        #expect(String(localized: TourPage.welcome.advanceTitle) == "Start")
        for lesson in Lesson.allCases.dropLast() {
            #expect(String(localized: TourPage.lesson(lesson).advanceTitle) == "Next")
        }
        #expect(String(localized: TourPage.all.last!.advanceTitle) == "Get Started")
    }

    @Test("Every page has its words, for fingers and for a pointer", arguments: Lesson.allCases)
    func nothingIsBlank(lesson: Lesson) {
        for pointing in [Pointing.touch, .pointer] {
            #expect(!String(localized: lesson.title(for: pointing)).isEmpty)
            #expect(!String(localized: lesson.instruction(for: pointing)).isEmpty)
            #expect(!String(localized: lesson.afterword(for: pointing)).isEmpty)
            #expect(!String(localized: TourCopy.welcomeBody(for: pointing)).isEmpty)
        }
        #expect(!String(localized: TourCopy.welcomePractice).isEmpty)
    }

    /// A Mac has no fingers on the board, and a phone no pointer.
    @Test("A Mac is never told to tap, nor a phone to click", arguments: Lesson.allCases)
    func eachSaysItsOwnVerb(lesson: Lesson) {
        let touch = [
            lesson.title(for: .touch), lesson.instruction(for: .touch),
            lesson.afterword(for: .touch),
        ]
        let pointer = [
            lesson.title(for: .pointer), lesson.instruction(for: .pointer),
            lesson.afterword(for: .pointer),
        ]
        for words in touch.map({ String(localized: $0) }) {
            #expect(!words.localizedCaseInsensitiveContains("click"), "\(words)")
        }
        for words in pointer.map({ String(localized: $0) }) {
            #expect(!words.localizedCaseInsensitiveContains("tap"), "\(words)")
        }
    }
}

/// Keeps `A11y.Tour`, the UI tests' copy of the pages' names, in step with `Lesson`.
@Suite("The UI tests' names for the pages")
struct TourPageIdentifierTests {
    @Test func theLessonPagesAreTheLessons() {
        #expect(Lesson.allCases.map(\.rawValue) == A11y.Tour.lessonPages)
    }

    @Test func everyPageHasItsOwnName() {
        #expect(TourPage.welcome.name == A11y.Tour.welcomePage)
        #expect(Set(TourPage.all.map(\.name)).count == TourPage.all.count)
    }
}

@Suite("When the tour is up")
struct OnboardingProgressTests {
    @Test func aFirstLaunchTakesTheTour() {
        #expect(OnboardingProgress.isDue(answered: 0))
    }

    @Test func onceAnsweredItStaysAway() {
        #expect(!OnboardingProgress.isDue(answered: OnboardingProgress.version))
    }

    @Test func aRevisedTourComesBack() {
        #expect(OnboardingProgress.isDue(answered: OnboardingProgress.version - 1))
    }

    @Test func anAnswerToALaterTourCounts() {
        #expect(!OnboardingProgress.isDue(answered: OnboardingProgress.version + 1))
    }
}

@Suite("Which window puts the tour up")
struct TourStageTests {
    @Test func oneWindowAtATime() {
        let stage = TourStage()
        let first = UUID()
        let second = UUID()

        #expect(stage.claim(for: first))
        #expect(!stage.claim(for: second))
        // Asking again, it still has it.
        #expect(stage.claim(for: first))

        stage.release(from: second)
        #expect(stage.presenter == first)
        stage.release(from: first)
        #expect(stage.claim(for: second))
    }
}

@Suite("Where a lesson's notes are")
struct PracticeLayoutTests {
    /// A board with the room the layouts are written for, and one smaller, as at large text sizes.
    static let boards = [Lesson.roomy, CGSize(width: 320, height: 400)]

    static func frame(_ note: Lesson.PracticeNote, on board: CGSize) -> CGRect {
        frame(around: Lesson.place(note.offset, in: board), side: note.side)
    }

    static func frame(around center: CGPoint, side: Double) -> CGRect {
        CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    }

    /// Whether a finger anywhere on `rect` would be over the bin: let go there, a drag deletes.
    static func reachesTheBin(_ rect: CGRect, on board: CGSize) -> Bool {
        let bin = TrashZone.center(in: board)
        let nearest = CGPoint(
            x: min(max(bin.x, rect.minX), rect.maxX), y: min(max(bin.y, rect.minY), rect.maxY))
        return TrashZone.contains(nearest, in: board)
    }

    @Test("Every note is wholly on the board", arguments: Lesson.allCases)
    func notesAreOnTheBoard(lesson: Lesson) {
        for board in Self.boards {
            for note in lesson.practice {
                let frame = Self.frame(note, on: board)
                #expect(CGRect(origin: .zero, size: board).contains(frame), "\(frame) on \(board)")
            }
        }
    }

    @Test("No note covers another", arguments: Lesson.allCases)
    func notesDontOverlap(lesson: Lesson) {
        for board in Self.boards {
            let frames = lesson.practice.map { Self.frame($0, on: board) }
            for (index, frame) in frames.enumerated() {
                for other in frames[(index + 1)...] {
                    #expect(!frame.intersects(other), "\(frame) and \(other) on \(board)")
                }
            }
        }
    }

    @Test("No note is within a drop of the bin", arguments: Lesson.allCases)
    func notesKeepClearOfTheBin(lesson: Lesson) {
        for board in Self.boards {
            for note in lesson.practice {
                let frame = Self.frame(note, on: board)
                #expect(!Self.reachesTheBin(frame, on: board), "\(frame) on \(board)")
            }
        }
    }

    @Test("The double tap lands on nothing, and what it adds covers nothing")
    func theDoubleTapLandsOnNothing() {
        for board in Self.boards {
            let spot = Lesson.place(Lesson.spot, in: board)
            let added = Demonstration.Rest.added(at: spot, on: board, after: .pink)
            let addedFrame = Self.frame(around: added.center, side: added.side)
            #expect(CGRect(origin: .zero, size: board).contains(addedFrame))
            for note in Lesson.doubleTapToAdd.practice {
                #expect(!Self.frame(note, on: board).contains(spot))
                #expect(!Self.frame(note, on: board).intersects(addedFrame))
            }
        }
    }

    @Test("Each lesson but the double tap's acts on a note it has", arguments: Lesson.allCases)
    func theDemonstratedNoteIsThere(lesson: Lesson) {
        if let index = lesson.demonstrated {
            #expect(lesson.practice.indices.contains(index))
        } else {
            #expect(lesson == .doubleTapToAdd)
        }
    }
}

@Suite("What a demonstration does")
struct DemonstrationTests {
    static let board = Lesson.roomy

    /// `lesson`'s demonstration `seconds` into its loop, or its still.
    private func demonstration(_ lesson: Lesson, at seconds: Double?) -> Demonstration {
        let rest =
            lesson.demonstrated.map { Demonstration.Rest(lesson.practice[$0], on: Self.board) }
            ?? .added(
                at: Lesson.place(Lesson.spot, in: Self.board), on: Self.board,
                after: lesson.practice.last?.color)
        return Demonstration(
            lesson: lesson, phase: seconds.map { $0 / Demonstration.loop(of: lesson) },
            board: Self.board, rest: rest)
    }

    private func isAtRest(_ demonstration: Demonstration) -> Bool {
        let look = demonstration.look
        let rest = demonstration.rest
        return look.center == rest.center && look.asked == rest.side && look.color == rest.color
            && look.text == rest.text && !look.isRaised && !look.isOverTrash && !look.isWriting
            && look.isGone == (demonstration.lesson == .doubleTapToAdd)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        hypot(a.x - b.x, a.y - b.y)
    }

    @Test("Both ends of the loop are the board at rest", arguments: Lesson.allCases)
    func theLoopRests(lesson: Lesson) {
        for phase in [0.0, Demonstration.loop(of: lesson)] {
            let demonstration = demonstration(lesson, at: phase)
            #expect(isAtRest(demonstration))
            #expect(
                !demonstration.showsBin && !demonstration.showsMenu && !demonstration.offersUndo)
            #expect(!demonstration.isAway)
            #expect(demonstration.fingers.allSatisfy { $0.presence == 0 && !$0.isDown })
        }
    }

    /// The board's own note is under the reader's finger whenever the demonstration hasn't taken
    /// it — so what the board shows then has to be that note, at rest.
    @Test("Whenever the board has its note back, the note is at rest", arguments: Lesson.allCases)
    func theNoteComesBackAtRest(lesson: Lesson) {
        let loop = Demonstration.loop(of: lesson)
        for seconds in stride(from: 0, through: loop, by: 0.05) {
            let demonstration = demonstration(lesson, at: seconds)
            if !demonstration.drawsNote {
                #expect(isAtRest(demonstration), "\(seconds)s in")
            }
            if demonstration.isAway {
                #expect(demonstration.drawsNote, "\(seconds)s in")
            }
        }
    }

    @Test("The gesture is shown done", arguments: Lesson.allCases)
    func theGestureCompletes(lesson: Lesson) throws {
        let landing = Demonstration.landing(of: lesson)
        let done = demonstration(lesson, at: landing)
        let rest = done.rest

        switch lesson {
        case .doubleTapToAdd:
            #expect(!done.look.isGone)
            #expect(done.look.center == rest.center)
            #expect(done.fingers[0].at == done.spot)
        case .tapToWrite:
            #expect(done.look.isWriting)
            let written = demonstration(lesson, at: 3.5)
            #expect(written.look.isWriting)
            #expect(written.look.text == rest.text + "\n" + String(localized: Lesson.written))
        case .dragToMove:
            #expect(distance(done.look.center, done.destination) < 0.001)
            #expect(!done.look.isRaised)
            #expect(!TrashZone.contains(done.destination, in: Self.board))
            #expect(
                CGRect(origin: .zero, size: Self.board).contains(
                    PracticeLayoutTests.frame(around: done.destination, side: rest.side)))
        case .pinchToResize:
            #expect(abs(done.look.asked - rest.side * Lesson.spread) < 0.001)
            #expect(NoteGeometry.clampSide(done.look.asked) == done.look.asked)
            #expect(!NoteGeometry.crumples(done.look.asked))
        case .holdForMenu:
            #expect(done.look.color == Lesson.picked)
            #expect(Lesson.picked != rest.color)
            #expect(done.showsMenu)
        case .dragToBin:
            let over = demonstration(lesson, at: landing - 0.05)
            #expect(TrashZone.contains(over.fingers[0].at, in: Self.board))
            #expect(over.look.isOverTrash)
            #expect(over.showsBin)
            #expect(done.look.isGone && done.offersUndo && !done.showsBin)
        case .pinchToCrumple:
            let crumpled = demonstration(lesson, at: landing - 0.05)
            #expect(NoteGeometry.crumples(crumpled.look.asked))
            #expect(done.look.isGone && done.offersUndo)
        }
    }

    @Test(
        "The hand lets go as what it did lands, and is gone by the rewind",
        arguments: Lesson.allCases)
    func theHandLetsGo(lesson: Lesson) {
        let landing = demonstration(lesson, at: Demonstration.landing(of: lesson))
        #expect(landing.fingers.allSatisfy { !$0.isDown })
        let rewind = demonstration(lesson, at: Demonstration.rewind(of: lesson))
        #expect(rewind.fingers.allSatisfy { $0.presence == 0 })
    }

    @Test("A pinch takes two fingers, and every other gesture one", arguments: Lesson.allCases)
    func fingerCountMatchesTheGesture(lesson: Lesson) {
        let expected = lesson == .pinchToResize || lesson == .pinchToCrumple ? 2 : 1
        #expect(demonstration(lesson, at: nil).fingers.count == expected)
        #expect(demonstration(lesson, at: 1).fingers.count == expected)
    }

    @Test("Every finger starts on the note it acts on", arguments: Lesson.allCases)
    func fingersStartOnTheNote(lesson: Lesson) {
        let still = demonstration(lesson, at: nil)
        guard lesson != .doubleTapToAdd else {
            #expect(still.fingers[0].at == still.spot)
            return
        }
        let note = PracticeLayoutTests.frame(around: still.rest.center, side: still.rest.side)
        for finger in still.fingers {
            #expect(note.contains(finger.at), "\(finger.at) off \(note)")
        }
    }

    @Test("The still shows each finger down where the gesture starts", arguments: Lesson.allCases)
    func theStillShowsTheStart(lesson: Lesson) {
        let still = demonstration(lesson, at: nil)
        #expect(still.fingers.allSatisfy { $0.isDown && $0.presence == 1 })
        #expect(isAtRest(still))
        #expect(!still.isAway && !still.drawsNote)
        #expect(still.showsBin == (lesson == .dragToBin))
        #expect(!still.showsMenu && !still.offersUndo)
        #expect(still.taps == (lesson == .doubleTapToAdd ? 2 : 1))
    }

    @Test("The beats are in order", arguments: Lesson.allCases)
    func theBeatsAreInOrder(lesson: Lesson) {
        let press = Demonstration.press(of: lesson)
        let landing = Demonstration.landing(of: lesson)
        let rewind = Demonstration.rewind(of: lesson)
        #expect(Demonstration.fade < press)
        #expect(press < landing)
        #expect(landing + Demonstration.fade < rewind)
        #expect(rewind + Demonstration.settle < Demonstration.loop(of: lesson))
    }

    @Test("The menu's colors are where its finger taps, clear of the note")
    func theMenuIsWhereTheFingerGoes() {
        let tap = demonstration(.holdForMenu, at: 2.0)
        let menu = tap.menu
        let swatch = menu.swatch(Lesson.picked)

        #expect(CGRect(origin: .zero, size: Self.board).contains(menu.frame))
        #expect(menu.frame.contains(swatch))
        #expect(tap.fingers[0].isDown)
        #expect(distance(tap.fingers[0].at, swatch) < 0.001)
        #expect(
            !menu.frame.intersects(
                PracticeLayoutTests.frame(around: tap.rest.center, side: tap.rest.side)))
        // The tap that puts it away is off it.
        #expect(!menu.frame.contains(tap.outside))
    }
}
