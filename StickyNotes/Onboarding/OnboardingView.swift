import AccessibilityIdentifiers
import SwiftUI

/// The tour: a welcome page, then a page per gesture with a board to practise it on. Not a
/// swipeable pager, whose swipe would fight the gestures being practised.
struct OnboardingView: View {
    /// On the Mac, where the tour is a sheet as big as what is in it: room for the longest page's
    /// words over a board with room round its notes, and short enough for a window opened at its
    /// default size. Unscaled, since a sheet that grew with the text size would move under the
    /// reader on the way through.
    static let macSize = CGSize(width: 520, height: 640)

    @Environment(\.dismiss) private var dismiss
    @Environment(\.motion) private var motion
    @Environment(\.dynamicTypeSize) private var typeSize

    private var progress = OnboardingProgress()

    @State private var page: TourPage = .welcome
    /// Lessons done on their boards, across pages.
    @State private var learned: Set<Lesson> = []

    /// Room at the end of the title for Skip, which sits over it.
    @ScaledMetric(relativeTo: .body) private var skipGutter: CGFloat = 64

    private static let margin: CGFloat = 24
    /// Wide enough for a board with room round its notes; on an iPad, no wider.
    private static let width: CGFloat = 560
    private static let boardRadius: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch page {
            case .welcome:
                // In the middle, and scrolling once the largest text sizes make it taller than the
                // page. A lesson's page can't scroll: its swipe would fight the board's gestures.
                ScrollView { words }
                    .scrollBounceBehavior(.basedOnSize)
                    .defaultScrollAnchor(.center, for: .alignment)
            case .lesson(let lesson):
                words
                board(for: lesson)
            }
            footer
        }
        .padding(.horizontal, Self.margin)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .frame(maxWidth: Self.width, maxHeight: .infinity, alignment: .topLeading)
        // Within the page's width, so Skip stays near the title on a wide screen.
        .overlay(alignment: .topTrailing) { skip }
        .frame(maxWidth: .infinity)
        .background(.background)
        // Without `.contain`, the identifier would land on every control inside.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11y.Tour.view)
    }

    /// Whether the page's gesture has been done. The welcome page has none to do.
    private var isLearned: Bool {
        guard let lesson = page.lesson else { return true }
        return learned.contains(lesson)
    }

    // MARK: - The page

    /// The title, and what to do, as tall as they are: the board has what is left.
    private var words: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title.weight(.semibold))
                .padding(.trailing, skipGutter)
                .accessibilityAddTraits(.isHeader)

            switch page {
            case .welcome:
                Text(TourCopy.welcomeBody)
                Text(TourCopy.welcomePractice)
                    .padding(.top, 12)
            case .lesson(let lesson):
                instruction(for: lesson)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        // Identity per page, so the words cross-fade while the controls stay put.
        .id(page)
        .transition(.opacity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11y.Tour.page(page.name))
    }

    private var title: LocalizedStringResource {
        switch page {
        case .welcome: TourCopy.welcomeTitle
        case .lesson(let lesson): lesson.title
        }
    }

    /// The instruction, and in its place once the gesture is done, the afterword.
    private func instruction(for lesson: Lesson) -> some View {
        let isLearned = learned.contains(lesson)

        return Label {
            // Both laid out, so whichever is taller sets the height, and the board stays put when
            // the afterword replaces the instruction.
            ZStack(alignment: .topLeading) {
                Text(lesson.instruction).hidden()
                Text(lesson.afterword).hidden()
                Text(isLearned ? lesson.afterword : lesson.instruction)
            }
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.tint)
                .opacity(isLearned ? 1 : 0)
                .frame(width: isLearned ? nil : 0)
        }
        // Said to VoiceOver, for which the check mark is only a picture.
        .accessibilityValue(
            isLearned
                ? Text(
                    "Practiced",
                    comment: "VoiceOver, after a tour page's instruction, once its gesture is done."
                )
                : Text(verbatim: "")
        )
        .accessibilityIdentifier(A11y.Tour.instruction)
        .animation(motion.pageTurn, value: isLearned)
    }

    private func board(for lesson: Lesson) -> some View {
        PracticeBoard(lesson: lesson) { learn(lesson) }
            // A fresh board per lesson.
            .id(lesson)
            .clipShape(.rect(cornerRadius: Self.boardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Self.boardRadius)
                    .strokeBorder(.separator)
            }
            .frame(maxHeight: .infinity)
            .transition(.opacity)
    }

    // MARK: - Getting about

    /// The dots beside the way on, or over it at the largest text sizes, where the way on needs
    /// the width.
    private var footer: some View {
        let layout =
            typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            dots
                .frame(maxWidth: .infinity, alignment: .leading)
            advance
        }
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(TourPage.all) { step in
                Circle()
                    .fill(step == page ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .animation(motion.pageTurn, value: page)
        // Big enough to land VoiceOver on, though only a picture of where the tour is: its frame
        // would otherwise be the dots'.
        .frame(minHeight: 44)
        .contentShape(.accessibility, .rect)
        .accessibilityElement()
        .accessibilityLabel(
            Text(
                "Step \(page.position + 1) of \(TourPage.all.count)",
                comment:
                    "VoiceOver label for the tour's page dots: which page this is, of how many."
            ))
    }

    /// Filled once the page's gesture is done. Never disabled: not everyone can do every gesture.
    /// In primary, not the accent: white on the accent, as on gray, falls short of the contrast
    /// the accessibility audit asks of text this size.
    @ViewBuilder
    private var advance: some View {
        if isLearned {
            advanceButton.buttonStyle(.borderedProminent)
        } else {
            advanceButton.buttonStyle(.bordered)
        }
    }

    private var advanceButton: some View {
        Button {
            go()
        } label: {
            Text(page.advanceTitle)
                .fontWeight(.semibold)
        }
        .controlSize(.large)
        .tint(.primary)
        .accessibilityIdentifier(A11y.Tour.advanceButton)
    }

    private var skip: some View {
        // Plain and primary: the accent falls short of the audit's contrast on the background.
        Button {
            finish()
        } label: {
            // The frame is the hit area, with the word at its end, on the page's margin.
            Text("Skip", comment: "Leaves the tour, from any of its pages.")
                .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
        .accessibilityIdentifier(A11y.Tour.skipButton)
        .padding(.horizontal, Self.margin)
    }

    private func learn(_ lesson: Lesson) {
        withAnimation(motion.pageTurn) { _ = learned.insert(lesson) }
    }

    private func go() {
        guard let next = page.next else { return finish() }
        withAnimation(motion.pageTurn) { page = next }
    }

    private func finish() {
        progress.markSeen()
        dismiss()
    }
}

#Preview {
    OnboardingView()
}
