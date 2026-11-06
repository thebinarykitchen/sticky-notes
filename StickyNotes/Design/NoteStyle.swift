import NoteModel
import SwiftUI

/// How a note is drawn. Notes are paper: the same colors in light and dark, with dark ink, so
/// contrast holds in both.
enum NoteStyle {
    static let ink = Color(white: 0.12)
    static let placeholder = Color(white: 0.12).opacity(0.45)
    static let cornerRadius: CGFloat = 4
    static let padding: CGFloat = 14

    /// Resting and lifted shadow radii.
    static let shadow: CGFloat = 3
    static let liftedShadow: CGFloat = 12
    static let liftedScale: CGFloat = 1.04
}

extension NoteColor {
    var fill: Color {
        switch self {
        case .yellow: Color(red: 1.00, green: 0.92, blue: 0.55)
        case .pink: Color(red: 1.00, green: 0.78, blue: 0.84)
        case .blue: Color(red: 0.71, green: 0.86, blue: 1.00)
        case .green: Color(red: 0.77, green: 0.93, blue: 0.70)
        case .orange: Color(red: 1.00, green: 0.80, blue: 0.60)
        case .purple: Color(red: 0.84, green: 0.78, blue: 1.00)
        case .teal: Color(red: 0.66, green: 0.91, blue: 0.89)
        case .gray: Color(red: 0.86, green: 0.86, blue: 0.84)
        }
    }

    /// What VoiceOver calls a note of this color.
    var accessibilityName: LocalizedStringResource {
        switch self {
        case .yellow: LocalizedStringResource("Yellow note", comment: "VoiceOver name for a note.")
        case .pink: LocalizedStringResource("Pink note", comment: "VoiceOver name for a note.")
        case .blue: LocalizedStringResource("Blue note", comment: "VoiceOver name for a note.")
        case .green: LocalizedStringResource("Green note", comment: "VoiceOver name for a note.")
        case .orange:
            LocalizedStringResource("Orange note", comment: "VoiceOver name for a note.")
        case .purple:
            LocalizedStringResource("Purple note", comment: "VoiceOver name for a note.")
        case .teal: LocalizedStringResource("Teal note", comment: "VoiceOver name for a note.")
        case .gray: LocalizedStringResource("Gray note", comment: "VoiceOver name for a note.")
        }
    }

    /// The color as a note's menu offers it.
    var name: LocalizedStringResource {
        switch self {
        case .yellow: LocalizedStringResource("Yellow", comment: "A color in a note's menu.")
        case .pink: LocalizedStringResource("Pink", comment: "A color in a note's menu.")
        case .blue: LocalizedStringResource("Blue", comment: "A color in a note's menu.")
        case .green: LocalizedStringResource("Green", comment: "A color in a note's menu.")
        case .orange: LocalizedStringResource("Orange", comment: "A color in a note's menu.")
        case .purple: LocalizedStringResource("Purple", comment: "A color in a note's menu.")
        case .teal: LocalizedStringResource("Teal", comment: "A color in a note's menu.")
        case .gray: LocalizedStringResource("Gray", comment: "A color in a note's menu.")
        }
    }

    /// What VoiceOver calls making a note this color.
    var accessibilityActionName: LocalizedStringResource {
        switch self {
        case .yellow:
            LocalizedStringResource(
                "Make Yellow", comment: "VoiceOver action that recolors a note.")
        case .pink:
            LocalizedStringResource("Make Pink", comment: "VoiceOver action that recolors a note.")
        case .blue:
            LocalizedStringResource("Make Blue", comment: "VoiceOver action that recolors a note.")
        case .green:
            LocalizedStringResource("Make Green", comment: "VoiceOver action that recolors a note.")
        case .orange:
            LocalizedStringResource(
                "Make Orange", comment: "VoiceOver action that recolors a note.")
        case .purple:
            LocalizedStringResource(
                "Make Purple", comment: "VoiceOver action that recolors a note.")
        case .teal:
            LocalizedStringResource("Make Teal", comment: "VoiceOver action that recolors a note.")
        case .gray:
            LocalizedStringResource("Make Gray", comment: "VoiceOver action that recolors a note.")
        }
    }
}
