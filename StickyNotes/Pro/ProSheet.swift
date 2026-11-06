import AccessibilityIdentifiers
import NoteModel
import StoreKit
import SwiftData
import SwiftUI

/// The Pro purchase sheet, shown when something free runs out, or from the list of boards or the
/// menu bar.
///
/// What brought the sheet up leads the offers, so it shows the reader what they just met rather
/// than leaving the header to say it alone; a color picked for a note is shown on the note.
struct ProSheet: View {
    let reason: ProOffer.Reason

    @Environment(Pro.self) private var pro
    @Environment(NoteStore.self) private var store
    @Environment(\.noteWriter) private var writer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.motion) private var motion
    /// Carries this sheet's window, so the payment sheet opens over it. See ``Pro/buy(with:)``.
    @Environment(\.purchase) private var purchase

    /// Loading the product or purchasing.
    @State private var isWorking = false
    @State private var isRestoring = false
    /// What the last purchase or restore came to, under the buttons. Nil when there's nothing to
    /// say.
    @State private var message: LocalizedStringResource?
    /// False until the sheet is on screen, so the offers can arrive rather than be there.
    @State private var hasArrived = false

    private var ranOutOf: ProFeature? { reason.feature }

    /// The gap between offer cards.
    private static let cardGap: CGFloat = 8
    private static let cardRadius: CGFloat = 12
    /// The icon column, so every offer's words start at the same place.
    private static let symbolColumn: CGFloat = 26
    /// The delay between one offer's arrival and the next.
    private static let arrivalStep: Double = 0.04
    /// The note a picked color is shown on.
    private static let trialSide: CGFloat = 120
    /// The sheet's size on a Mac, where a sheet is as big as what is in it. Ignored elsewhere,
    /// where a sheet is given its size.
    private static let onAMac = CGSize(width: 420, height: 620)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if let trial = reason.trying { trialNote(trial) }
                    offers
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, Self.cardGap)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Pinned below the scroll view.
            .safeAreaInset(edge: .bottom) { actions }
            .toolbar {
                // The system's cross, as Make Notes has: a text button here fails the
                // accessibility audit on iOS 27.
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(A11y.Pro.sheet)
        }
        .frame(idealWidth: Self.onAMac.width, idealHeight: Self.onAMac.height)
        // The page's own background, as on an iPhone: an iPad's sheet is gray by default, which
        // the cards vanish into and the opaque actions don't match.
        .presentationBackground(.background)
        // Retry loading the product if earlier attempts failed.
        .task {
            guard pro.product == nil else { return }
            isWorking = true
            await pro.refresh()
            isWorking = false
        }
        // Unlocked, including by a purchase made elsewhere: the color picked is given to the
        // note, and the sheet goes.
        .onChange(of: pro.isUnlocked) { _, unlocked in
            guard unlocked else { return }
            if let trial = reason.trying, !trial.note.isDeleted, trial.note.modelContext != nil {
                store.recolor(trial.note, to: trial.color)
            }
            dismiss()
        }
    }

    /// No symbol of its own: the offers below carry the sheet's pictures, and an icon here costs
    /// a card's worth of the first screenful.
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(headline)
                .font(.title2.weight(.semibold))
            Text(explanation)
        }
        .foregroundStyle(.primary)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(A11y.Pro.reason(reason.id))
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

    /// The offers, the one that ran out first and the rest under their own heading.
    private var offers: some View {
        VStack(alignment: .leading, spacing: Self.cardGap) {
            if let ranOutOf {
                card(for: ranOutOf, isWhatRanOut: true, place: 0)

                Text("Also in Pro", comment: "Heads the rest of what Pro adds, on the Pro sheet.")
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 8)
            }

            ForEach(Array(rest.enumerated()), id: \.element) { place, feature in
                card(for: feature, isWhatRanOut: false, place: place)
            }
        }
        .onAppear { hasArrived = true }
    }

    /// Everything but the feature that brought the sheet up, which leads on its own. Make Notes
    /// only where it can run: Apple Intelligence adds, and never replaces, and a device without
    /// it isn't sold it.
    private var rest: [ProFeature] {
        ProFeature.allCases.filter {
            $0 != ranOutOf && ($0 != .makeNotes || writer.isAvailable)
        }
    }

    /// One offer: what Pro gives, and what of it is free. The card for what ran out is bordered,
    /// so the reason the sheet appeared is visible rather than only written.
    ///
    /// `place` is where it stands in the run, which is what staggers its arrival.
    private func card(for feature: ProFeature, isWhatRanOut: Bool, place: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: feature.symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: Self.symbolColumn, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.offer)
                    .font(.callout.weight(.medium))
                // Primary, not secondary: gray on the card fails the contrast audit.
                Text(isWhatRanOut ? feature.exhausted : feature.allowance)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.background.secondary, in: .rect(cornerRadius: Self.cardRadius))
        .overlay {
            if isWhatRanOut {
                RoundedRectangle(cornerRadius: Self.cardRadius)
                    .strokeBorder(.tint, lineWidth: 2)
            }
        }
        .accessibilityElement(children: .combine)
        // The run arrives rather than being there. Nothing under Reduce Motion, where
        // `Motion.edit` is nil and the delay has nothing to delay.
        .opacity(hasArrived ? 1 : 0)
        .offset(y: hasArrived ? 0 : 10)
        .animation(motion.edit?.delay(Double(place) * Self.arrivalStep), value: hasArrived)
    }

    private var actions: some View {
        VStack(spacing: 8) {
            price

            // The whole argument, next to the price rather than buried in the header — and true
            // whether or not the product loaded.
            Text(
                "One-time purchase. No subscription.",
                comment: "Under the Pro sheet's buy button."
            )
            .font(.footnote)

            Button {
                Task { await restore() }
            } label: {
                if isRestoring {
                    ProgressView().controlSize(.small)
                } else {
                    Text(
                        "Restore Purchases",
                        comment: "Asks the App Store for a Pro bought before, on the Pro sheet.")
                }
            }
            .font(.footnote)
            // Drawn as its label, in primary, like the line above it.
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            // 44pt minimum hit target.
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(.rect)
            // One store request at a time: each sync can ask the reader to sign in.
            .disabled(isRestoring || isWorking)
            .accessibilityIdentifier(A11y.Pro.restoreButton)

            if let message {
                Text(message)
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(A11y.Pro.message)
            }
        }
        .multilineTextAlignment(.center)
        // Primary, the buttons included: secondary text, accent-colored text and white on an
        // accent-tinted button all fail the contrast audit on iOS 27.
        .tint(.primary)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        // Opaque, not `.bar`: over the material, Restore Purchases failed the contrast audit
        // however it was drawn.
        .background(.background)
        .overlay(alignment: .top) { Divider() }
    }

    /// The buy button with the price, a spinner while loading, or Try Again — never a disabled
    /// button without a price.
    @ViewBuilder
    private var price: some View {
        if let price = pro.price {
            Button {
                Task { await buy() }
            } label: {
                Text(
                    "Unlock Pro for \(price)",
                    comment:
                        "The Pro sheet's buy button. The argument is the price, already formatted for the reader's App Store."
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isWorking || isRestoring)
            .accessibilityIdentifier(A11y.Pro.buyButton)
        } else if isWorking {
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, minHeight: 50)
        } else {
            Button {
                Task {
                    isWorking = true
                    await pro.refresh()
                    isWorking = false
                }
            } label: {
                Text(
                    "Try Again",
                    comment:
                        "On the Pro sheet, in place of the buy button, when the price didn't load.")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier(A11y.Pro.retryButton)
        }
    }

    /// Buys Pro, saying so when the purchase is waiting or didn't go through. Nothing is said once
    /// it's bought: the sheet is on its way down.
    private func buy() async {
        message = nil
        isWorking = true
        let outcome = await pro.buy(with: purchase)
        isWorking = false

        switch outcome {
        case .pending:
            message = LocalizedStringResource(
                "Waiting for approval. Pro will unlock once the purchase is approved.",
                comment:
                    "On the Pro sheet, when the purchase waits for approval, as Ask to Buy does.")
        case .failed:
            message = LocalizedStringResource(
                "The purchase didn't go through. Try again.",
                comment: "On the Pro sheet, when buying Pro failed.")
        case .done, .cancelled:
            break
        }
    }

    /// Restores purchases. Success dismisses, and a cancelled sign-in says nothing.
    private func restore() async {
        message = nil
        isRestoring = true
        let outcome = await pro.restore()
        isRestoring = false

        switch outcome {
        case .done where !pro.isUnlocked:
            message = LocalizedStringResource(
                "No purchases to restore for this Apple Account.",
                comment: "On the Pro sheet, when Restore Purchases found nothing.")
        case .failed:
            message = LocalizedStringResource(
                "Couldn't restore your purchases. Try again.",
                comment: "On the Pro sheet, when Restore Purchases failed.")
        case .done, .pending, .cancelled:
            break
        }
    }

    private var headline: LocalizedStringResource {
        ranOutOf?.headline
            ?? LocalizedStringResource(
                "Sticky Notes Pro",
                comment: "The name of the one thing this app sells, and the Pro sheet's title.")
    }

    private var explanation: LocalizedStringResource {
        ranOutOf?.explanation
            ?? LocalizedStringResource(
                "One purchase lifts every limit below.",
                comment: "Under the Pro sheet's title, when it was opened from the list of boards.")
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
