import AccessibilityIdentifiers
import NoteModel
import PurchaseUI
import SwiftData
import SwiftUI

/// The Pro purchase sheet, shown when something free runs out, or from the list of boards or the
/// menu bar. A color picked for a note is shown on the note.
struct ProSheet: View {
    let reason: ProOffer.Reason

    @Environment(Pro.self) private var pro
    @Environment(NoteStore.self) private var store
    @Environment(\.noteWriter) private var writer
    @Environment(\.motion) private var motion

    /// The note a picked color is shown on.
    private static let trialSide: CGFloat = 120

    /// Make Notes only where it can run: Apple Intelligence adds, and never replaces, and a device
    /// without it isn't sold it.
    private var features: [ProFeature] {
        ProFeature.allCases.filter { $0 != .makeNotes || writer.isAvailable }
    }

    var body: some View {
        PurchaseSheet(
            purchase: pro.purchase,
            features: features,
            reason: reason.feature,
            title: LocalizedStringResource(
                "Sticky Notes Pro",
                comment: "The name of the one thing this app sells, and the Pro sheet's title."),
            overview: LocalizedStringResource(
                "One purchase lifts every limit below.",
                comment: "Under the Pro sheet's title, when it was opened from the list of boards."),
            identifiers: PurchaseSheetIdentifiers(
                sheet: A11y.Pro.sheet,
                reason: A11y.Pro.reason(reason.id),
                buyButton: A11y.Pro.buyButton,
                retryButton: A11y.Pro.retryButton,
                restoreButton: A11y.Pro.restoreButton,
                message: A11y.Pro.message
            ),
            reducesMotion: motion.edit == nil,
            macSize: CGSize(width: 420, height: 620),
            // Unlocked, including by a purchase made elsewhere: the color picked is given to the
            // note.
            onUnlock: {
                if let trial = reason.trying, !trial.note.isDeleted, trial.note.modelContext != nil
                {
                    store.recolor(trial.note, to: trial.color)
                }
            },
            lead: {
                if let trial = reason.trying { trialNote(trial) }
            }
        )
    }

    /// The note the color was picked for, in that color, so the color is seen rather than named.
    private func trialNote(_ trial: ProOffer.Trial) -> some View {
        Text(verbatim: trial.note.text)
            .foregroundStyle(NoteStyle.ink)
            .font(.callout)
            .lineLimit(4)
            .notePaper(side: Self.trialSide, color: trial.color)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(trial.color.accessibilityName))
    }
}

#Preview("Ran out") {
    Text(verbatim: "Board")
        .sheet(isPresented: .constant(true)) {
            ProSheet(reason: .init(feature: .boards))
        }
        .environment(Pro())
        .previewNotes(seeded: true)
}

#Preview("From the list") {
    Text(verbatim: "Board")
        .sheet(isPresented: .constant(true)) {
            ProSheet(reason: .init(feature: nil))
        }
        .environment(Pro())
        .previewNotes(seeded: true)
}

#Preview("Trying a color") {
    let container = PreviewNotes.container(seeded: true)
    let note = try! container.mainContext.fetch(FetchDescriptor<Note>()).first!
    Text(verbatim: "Board")
        .sheet(isPresented: .constant(true)) {
            ProSheet(reason: .init(feature: .colors, trying: .init(note: note, color: .purple)))
        }
        .environment(Pro())
        .previewNotes(container)
}
