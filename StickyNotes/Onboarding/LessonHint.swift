import AccessibilityIdentifiers
import SwiftUI

/// A gesture the reader hasn't done — the tour was skipped, or pressed through — named at the
/// foot of a board that now has notes enough to do it on. Goes for good once the gesture is done
/// or the hint is dismissed; see ``OnboardingProgress/hint(notes:)``.
struct LessonHint: View {
    let lesson: Lesson
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            // Marks it as about the board rather than one more note on it.
            Image(systemName: "hand.point.up.left")
                .font(.headline)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title)
                    .font(.headline)
                Text(lesson.instruction)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Label {
                    Text(
                        "Dismiss hint",
                        comment: "VoiceOver label for the button that closes a gesture's hint.")
                } icon: {
                    Image(systemName: "xmark")
                }
                .labelStyle(.iconOnly)
                .font(.body.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(A11y.Canvas.lessonHintDismiss)
        }
        // Primary throughout: a gray on the material is short of the contrast audit.
        .foregroundStyle(.primary)
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .padding(.vertical, 8)
        .frame(maxWidth: 480)
        .background(.regularMaterial, in: .rect(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11y.Canvas.lessonHint)
    }
}

#Preview {
    VStack {
        ForEach(Lesson.allCases) { lesson in
            LessonHint(lesson: lesson) {}
        }
    }
    .padding()
}
