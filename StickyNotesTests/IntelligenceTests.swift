import Foundation
import FoundationModels
import Testing

@testable import StickyNotes

struct NoteWriterTests {
    @Test func onlyAReadyModelInTheReadersLanguageIsOffered() {
        #expect(NoteWriter.offers(.available, speaksLocale: true))
        #expect(!NoteWriter.offers(.available, speaksLocale: false))
    }

    /// A device that can't run the model, Apple Intelligence turned off, the model still
    /// downloading.
    @Test(arguments: [
        SystemLanguageModel.Availability.UnavailableReason.deviceNotEligible,
        .appleIntelligenceNotEnabled, .modelNotReady,
    ])
    func anUnavailableModelOffersNothing(
        _ reason: SystemLanguageModel.Availability.UnavailableReason
    ) {
        #expect(!NoteWriter.offers(.unavailable(reason), speaksLocale: true))
    }

    @Test func turnedOffNothingIsOffered() {
        #expect(!NoteWriter(source: .off).isAvailable)
    }

    @Test func tidyingTrimsAndDropsBlanksAndExactRepeats() {
        #expect(
            NoteWriter.tidied([" Milk ", "", "Eggs\n", "   ", "Milk", "eggs"])
                == ["Milk", "Eggs", "eggs"])
    }

    /// Its case and punctuation aside.
    @Test func aNoteThatOnlySaysWhatWasWrittenRepeatsIt() {
        #expect(NoteWriter.repeats("Gift ideas for Dad", "gift ideas for dad.\n"))
        #expect(!NoteWriter.repeats("A new watch", "Gift ideas for Dad"))
    }

    @Test func theReaderIsToldWhyNotesCouldNotBeMade() {
        let tooLong = LanguageModelError.contextSizeExceeded(
            .init(contextSize: 4_096, tokenCount: 8_338, debugDescription: ""))
        #expect(NoteWriter.Failure(tooLong) == .tooLong)

        let declined: [LanguageModelError] = [
            .guardrailViolation(.init(debugDescription: "")),
            .refusal(.init(explanation: "", debugDescription: "")),
            .unsupportedLanguageOrLocale(
                .init(languageCode: Locale.LanguageCode("tlh"), debugDescription: "")),
        ]
        for error in declined {
            #expect(NoteWriter.Failure(error) == .declined)
        }

        #expect(
            NoteWriter.Failure(LanguageModelError.timeout(.init(debugDescription: ""))) == .failed)
        #expect(NoteWriter.Failure(CocoaError(.fileReadUnknown)) == .failed)
        #expect(NoteWriter.Failure(NoteWriter.Failure.declined) == .declined)
    }

    @Test func theStandInMakesANoteOfEachLineOrItem() async throws {
        let notes = try await NoteWriter(source: .fake).notes(from: "Milk, Eggs\nBread,, Milk\n")
        #expect(notes == ["Milk", "Eggs", "Bread"])
    }

    @Test func nothingToMakeANoteOfIsDeclined() async {
        await #expect(throws: NoteWriter.Failure.declined) {
            try await NoteWriter(source: .fake).notes(from: " ,\n, ")
        }
    }
}

/// Against the on-device model, wherever it can run: a Mac or an iPhone with Apple Intelligence,
/// and a Simulator on such a Mac, which uses the Mac's. Skipped everywhere else. These are what
/// a change to how `NoteWriter` asks it is tried against. One at a time: the model answers one at
/// a time anyway.
@Suite(.enabled(if: SystemLanguageModel.default.isAvailable), .serialized, .timeLimit(.minutes(1)))
struct NoteWriterModelTests {
    let writer = NoteWriter(source: .model)

    @Test func aListBecomesANoteForEachItemInTheWritersWords() async throws {
        let items = ["Milk", "Eggs", "Bread", "Pick up the dry cleaning", "Call the plumber"]
        #expect(try await writer.notes(from: items.joined(separator: "\n")) == items)
    }

    /// Asked only for notes, the model refused this list as unsafe, wrote ideas for it, or added
    /// a note of its own (seen on macOS 27).
    @Test(arguments: ["", "- "])
    func errandsAreNeitherRefusedNorAddedTo(bullet: String) async throws {
        let errands = ["Call the bank", "Renew passport", "Book flights to Rome"]
        let written = errands.map { bullet + $0 }.joined(separator: "\n")
        #expect(try await writer.notes(from: written) == errands)
    }

    @Test func aTopicBecomesIdeas() async throws {
        let notes = try await writer.notes(from: "weekend in Lisbon")
        #expect(notes.count >= 3)
        #expect(!notes.contains { NoteWriter.repeats($0, "weekend in Lisbon") })
    }

    /// The model takes this for a list of one, and hands it back as written.
    @Test func oneThingNamedBecomesIdeasRatherThanItself() async throws {
        let notes = try await writer.notes(from: "Gift ideas for Dad")
        #expect(notes.count >= 3)
        #expect(!notes.contains { NoteWriter.repeats($0, "Gift ideas for Dad") })
    }

    @Test func moreThanTheModelCanReadIsTooLong() async {
        let words = Array(repeating: "word", count: SystemLanguageModel.default.contextSize * 2)
        let error = await #expect(throws: (any Error).self) {
            try await writer.notes(from: words.joined(separator: " "))
        }
        #expect(error.map(NoteWriter.Failure.init) == .tooLong)
    }
}
