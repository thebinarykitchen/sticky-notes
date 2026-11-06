import FoundationModels
import LaunchArguments
import SwiftUI

/// Makes notes of what the reader writes, with the on-device model: a list, tasks or meeting
/// notes become a note for each item, in the reader's words; one thing named, a trip or a
/// project, becomes a few ideas for it. Offered only where the model can run in the reader's
/// language. The only file that imports `FoundationModels`.
///
/// How the model is asked was tried against it on macOS 27, each part for something it did
/// otherwise. It says which job it was given before it writes a note, or it took lists for
/// topics, refused ordinary lists as unsafe and lowercased the reader's words. The first ask is
/// greedy, or it now and then wrote the output format it is shown into a note. It still takes
/// some things named for lists of one, or heads its ideas with the topic, so a note that only
/// repeats what was written is dropped, and with none left it is asked again, for ideas alone.
/// `NoteWriterModelTests` checks the result against the model.
nonisolated struct NoteWriter: Sendable {
    /// Where notes come from: the on-device model; nowhere, so nothing is offered; or a stand-in
    /// for tests and previews, which makes a note of each line or comma-separated item.
    enum Source {
        case model, off, fake
    }

    let source: Source

    /// The source a launch asks for: ``LaunchFlag/noAppleIntelligence`` turns making notes off,
    /// and in Debug ``LaunchFlag/fakeAppleIntelligence`` asks for the stand-in. Read once, since
    /// launch arguments never change.
    static let launchSource: Source = {
        if LaunchFlag.noAppleIntelligence.isPresent() { return .off }
        #if DEBUG
            if LaunchFlag.fakeAppleIntelligence.isPresent() { return .fake }
        #endif
        return .model
    }()

    /// One for the process: each `SystemLanguageModel.default` is a new instance, which asks for
    /// its availability afresh, where one held answers at once (measured on macOS 27).
    private static let model = SystemLanguageModel.default

    /// Whether making notes is offered. The model is observable, so a body that reads this
    /// updates as the model becomes available, without a relaunch (seen on iOS 27.0, as a new
    /// Simulator's model got ready). That it updates as the model goes away isn't checked.
    var isAvailable: Bool {
        switch source {
        case .model: Self.offers(Self.model.availability, speaksLocale: Self.model.supportsLocale())
        case .off: false
        case .fake: true
        }
    }

    /// Only a model ready to run, in the reader's language. Any reason it is unavailable — a
    /// device that can't run it, Apple Intelligence turned off, the model still downloading —
    /// offers nothing.
    static func offers(_ availability: SystemLanguageModel.Availability, speaksLocale: Bool)
        -> Bool
    {
        availability == .available && speaksLocale
    }

    /// The notes to make of `text`, in order. Throws what the model throws, or a ``Failure`` of
    /// its own; ``Failure/init(_:)`` says what to tell the reader.
    @concurrent
    func notes(from text: String) async throws -> [String] {
        let notes: [String]
        switch source {
        case .model: notes = try await Self.write(text)
        case .fake: notes = Self.tidied(text.split { $0.isNewline || $0 == "," }.map(String.init))
        case .off: throw Failure.failed
        }
        guard !notes.isEmpty else { throw Failure.declined }
        return notes
    }

    /// A fresh session for each ask, so an earlier one can't sway the next.
    private static func write(_ text: String) async throws -> [String] {
        let written = try await LanguageModelSession(model: model, instructions: instructions)
            .respond(
                to: text, generating: WrittenNotes.self,
                options: GenerationOptions(samplingMode: .greedy)
            )
            .content.notes
        let notes = tidied(written).filter { !repeats($0, text) }
        guard notes.isEmpty else { return notes }
        let ideas = try await LanguageModelSession(model: model, instructions: ideasInstructions)
            .respond(to: text, generating: Ideas.self)
            .content.ideas
        return tidied(ideas).filter { !repeats($0, text) }
    }

    /// `notes`, trimmed, without blanks or exact repeats, in their order.
    static func tidied(_ notes: [String]) -> [String] {
        var seen = Set<String>()
        var tidied: [String] = []
        for note in notes {
            let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            if !note.isEmpty, seen.insert(note).inserted { tidied.append(note) }
        }
        return tidied
    }

    /// Whether `note` only says what was written, its case and punctuation aside.
    static func repeats(_ note: String, _ text: String) -> Bool {
        let edges = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        return note.trimmingCharacters(in: edges)
            .localizedCaseInsensitiveCompare(text.trimmingCharacters(in: edges)) == .orderedSame
    }

    // Not UI text, so not in the catalog. Reworded, the model has taken lists for topics again,
    // or topics for lists: try a change against `NoteWriterModelTests`.

    private static let instructions = """
        You turn what someone writes into sticky notes.
        If they wrote out items, tasks or notes, the job is a list: make one note for each \
        item, copying their words, spelling and capitalization exactly, in their order. Leave \
        out bullets and numbers. Add nothing.
        If they only named a topic, the job is a topic: write five to eight short ideas for it, \
        things to do, try or remember.
        Write in the language they wrote in.
        """

    private static let ideasInstructions = """
        You write sticky notes of ideas for what someone names: five to eight short ideas, \
        things to do, try or remember. Don't repeat what they named. Write in the language \
        they wrote in.
        """

    /// What went wrong, as the reader is told it.
    enum Failure: Error, Equatable {
        /// More than the model can read at once.
        case tooLong
        /// Something the model won't, or can't, make notes of: its guardrails stopped it, it
        /// refused, or the writing is in a language it doesn't speak.
        case declined
        /// Anything else.
        case failed

        /// What to tell the reader about `error`, thrown making notes.
        init(_ error: any Error) {
            switch error {
            case let failure as Failure:
                self = failure
            case LanguageModelError.contextSizeExceeded:
                self = .tooLong
            case LanguageModelError.guardrailViolation, LanguageModelError.refusal,
                LanguageModelError.unsupportedLanguageOrLocale:
                self = .declined
            default:
                self = .failed
            }
        }

        var message: LocalizedStringResource {
            switch self {
            case .tooLong:
                LocalizedStringResource(
                    "That's too long to make notes from. Try a shorter piece.",
                    comment: "Above what was written, when it is too long to make notes from.")
            case .declined:
                LocalizedStringResource(
                    "Can't make notes from that. Try different words.",
                    comment: "Above what was written, when no notes can be made from it.")
            case .failed:
                LocalizedStringResource(
                    "Couldn't make notes just now. Try again.",
                    comment: "Above what was written, when making notes failed.")
            }
        }
    }
}

/// What the model writes. Properties are generated in order, so it says which job it was given
/// before it writes a note.
@Generable private nonisolated struct WrittenNotes {
    @Generable nonisolated enum Job {
        case list, topic
    }

    @Guide(
        description:
            "list if the user wrote out items, tasks or notes; topic if they only named something to have ideas about."
    )
    var job: Job

    // Past its limit the model drops the rest of a list, or crams them into the last note (seen
    // at 20 on macOS 27). 50 takes a long shopping list.
    @Guide(description: "The notes, each a few words: one item, task or idea.", .count(1...50))
    var notes: [String]
}

/// Ideas for one thing named, when the first ask hands it back as written.
@Generable private nonisolated struct Ideas {
    @Guide(
        description: "Short ideas for it, each a few words: things to do, try or remember.",
        .count(1...8))
    var ideas: [String]
}

extension EnvironmentValues {
    /// Where notes are made: as the launch asked, unless a preview or test says otherwise.
    @Entry var noteWriter = NoteWriter(source: NoteWriter.launchSource)
}
