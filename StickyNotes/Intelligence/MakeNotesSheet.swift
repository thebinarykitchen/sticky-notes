import Accessibility
import AccessibilityIdentifiers
import SwiftUI

/// Asks for something to make notes from — a list, tasks or meeting notes to turn into notes, or
/// a topic to have ideas for — then hands the notes made to `onMake` and closes. A failure is
/// told above what was written, which stays, to be changed and tried again. Cancelled or
/// swiped away while the notes are being made, it stops, and makes none.
struct MakeNotesSheet: View {
    let onMake: ([String]) -> Void

    @Environment(\.noteWriter) private var writer
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var request: Request?
    @State private var failure: NoteWriter.Failure?
    @FocusState private var isFocused: Bool

    /// One go at making notes. Each is a new one, so trying the same text again after a failure
    /// runs again.
    struct Request: Equatable {
        let text: String
        private let attempt = UUID()
    }

    private var isMaking: Bool { request != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        text: $text,
                        prompt: Text(
                            "Paste a list to turn into notes, or name a topic for ideas",
                            comment: "Placeholder in the field notes are made from."),
                        axis: .vertical
                    ) {
                        Text(
                            "What to make notes from",
                            comment: "VoiceOver label for the field notes are made from.")
                    }
                    .lineLimit(4...12)
                    .focused($isFocused)
                    .disabled(isMaking)
                    .accessibilityIdentifier(A11y.MakeNotes.text)
                } header: {
                    // Above what was written: below it, the keyboard coming back or a long piece
                    // of writing hid it (seen on iOS 27).
                    if let failure {
                        Text(failure.message)
                    }
                }
            }
            // Said of what was written, which has changed.
            .onChange(of: text) { failure = nil }
            .formStyle(.grouped)
            .navigationTitle(
                Text("Make Notes", comment: "Opens the sheet that makes notes, and its title.")
            )
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        request = nil
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isMaking {
                        // Spoken only: drawn in the bar, the label hangs below it, clipped.
                        ProgressView()
                            .accessibilityLabel(
                                Text(
                                    "Making notes…",
                                    comment: "What VoiceOver says while notes are being made."))
                    } else {
                        // A checkmark, as the system's Cancel is a cross. As text, the
                        // accessibility audit found it clipped, too faint, and fixed in size.
                        Button(role: .confirm) {
                            failure = nil
                            request = Request(text: text)
                        } label: {
                            Label {
                                Text(
                                    "Add Notes",
                                    comment:
                                        "Makes and adds the notes: the button that does, and what Undo and Redo call it."
                                )
                            } icon: {
                                Image(systemName: "checkmark")
                            }
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier(A11y.MakeNotes.addButton)
                    }
                }
            }
        }
        .task(id: request) { await make() }
        .onAppear { isFocused = true }
        .presentationDetents([.medium, .large])
    }

    private func make() async {
        guard let request else { return }
        do {
            let notes = try await writer.notes(from: request.text)
            // Cancelled while the notes were being made.
            guard !Task.isCancelled else { return }
            onMake(notes)
            dismiss()
        } catch is CancellationError {
            // Cancelled: nothing to tell.
        } catch {
            let failure = NoteWriter.Failure(error)
            self.failure = failure
            self.request = nil
            // The button that was pressed has come back; the reason is above the field.
            AccessibilityNotification.Announcement(String(localized: failure.message)).post()
        }
    }
}

#Preview {
    MakeNotesSheet { _ in }
        .environment(\.noteWriter, NoteWriter(source: .fake))
}
