import AccessibilityIdentifiers
import NoteModel
import SwiftUI

/// The colors Pro adds, as notes, on every Pro sheet whatever brought it up: the paper shows
/// what the names alone would have to describe. The one picked for a note, if any, is outlined,
/// so the reason the sheet came up is seen as well.
struct ProColorGallery: View {
    /// The color picked for a note, or nil when nothing was.
    var picked: NoteColor?

    /// Every color a note is never handed, which is what `Pro.allows(_:)` keeps for Pro.
    static let colors = NoteColor.allCases.filter { !NoteColor.handedOut.contains($0) }

    private static let side: CGFloat = 64
    private static let pickedRadius: CGFloat = NoteStyle.cornerRadius + 4

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(Self.colors, id: \.self) { color in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: NoteStyle.cornerRadius)
                            .fill(color.fill)
                            .frame(width: Self.side, height: Self.side)
                            .shadow(color: .black.opacity(0.15), radius: NoteStyle.shadow, y: 1)
                            .padding(4)
                            .overlay {
                                if color == picked {
                                    RoundedRectangle(cornerRadius: Self.pickedRadius)
                                        .strokeBorder(.tint, lineWidth: 2)
                                }
                            }
                        Text(color.name)
                            .font(.caption)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(color == picked ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        // Out to the sheet's edges as it scrolls, rather than cut off at its margins.
        .scrollClipDisabled()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11y.Pro.colorGallery)
    }
}

#Preview("Nothing picked") {
    ProColorGallery()
        .padding()
}

#Preview("Purple picked") {
    ProColorGallery(picked: .purple)
        .padding()
}
