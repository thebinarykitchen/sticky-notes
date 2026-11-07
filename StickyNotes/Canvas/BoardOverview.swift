import AccessibilityIdentifiers
import NoteModel
import SwiftData
import SwiftUI

/// Every note on a board at once: the board shrunk to fit a sheet, since the canvas itself can't
/// zoom. A note picked goes to `onPick`, and the sheet closes.
///
/// A touch lands on the map, not on a note, and picks the note nearest it: on a big board a note is
/// drawn smaller than a finger. Each note is still its own button to VoiceOver.
struct BoardOverview: View {
    /// Back to front, as the canvas draws them.
    let notes: [Note]
    let onPick: (Note) -> Void

    /// How far from a note a touch still picks it.
    private static let reach: CGFloat = 22
    private static let inset: CGFloat = 16

    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var frames: [CGRect] { notes.map(CanvasScrolling.frame(of:)) }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                map(OverviewFit(frames: frames, in: proxy.size))
            }
            .padding(Self.inset)
            .background(.background.secondary)
            .navigationTitle(Text("All Notes", comment: "The title of a board's overview."))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() }
                }
            }
        }
        .overviewSheetSize()
    }

    private func map(_ fit: OverviewFit) -> some View {
        NotePlacement {
            ForEach(notes) { note in
                miniature(of: note, scale: fit.scale)
                    .layoutValue(key: NoteCenter.self, value: fit.point(fromBoard: note.center))
            }
        }
        .contentShape(.rect)
        .onTapGesture { location in
            if let index = fit.nearest(to: location, among: frames, within: Self.reach) {
                pick(notes[index])
            }
        }
    }

    /// The note as the canvas draws it, scaled down whole so its words stay where they fall on it.
    private func miniature(of note: Note, scale: CGFloat) -> some View {
        let text = store.text(of: note)
        return NoteView.words(text)
            .notePaper(side: note.side, color: note.color)
            .scaleEffect(scale)
            .frame(width: note.side * scale, height: note.side * scale)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                text.isEmpty
                    ? Text("Empty note", comment: "VoiceOver name for a note with no words on it.")
                    : Text(verbatim: text)
            )
            .accessibilityHint(
                Text(
                    "Shows it on the board.", comment: "VoiceOver hint for a note in the overview.")
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { pick(note) }
            .accessibilityIdentifier(A11y.Overview.note)
    }

    private func pick(_ note: Note) {
        onPick(note)
        dismiss()
    }
}

/// Where a board's notes fall in the overview: scaled down to fit, never up, and centred.
nonisolated struct OverviewFit {
    let scale: CGFloat
    private let center: CGPoint
    private let boardCenter: CGPoint

    /// `frames` in board points, and the `size` to fit them in.
    init(frames: [CGRect], in size: CGSize) {
        center = CGPoint(x: size.width / 2, y: size.height / 2)
        guard let bounds = frames.reduce(nil as CGRect?, { $0?.union($1) ?? $1 }) else {
            scale = 1
            boardCenter = .zero
            return
        }
        scale = min(1, size.width / bounds.width, size.height / bounds.height)
        boardCenter = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    func point(fromBoard point: CGPoint) -> CGPoint {
        CGPoint(
            x: center.x + (point.x - boardCenter.x) * scale,
            y: center.y + (point.y - boardCenter.y) * scale)
    }

    /// The index of the frame nearest `point`, in overview points, if any is within `reach`. Of
    /// frames equally near, as overlapping ones under the point are, the last: the one on top.
    func nearest(to point: CGPoint, among frames: [CGRect], within reach: CGFloat) -> Int? {
        var nearest: (index: Int, distance: CGFloat)?
        for (index, frame) in frames.enumerated() {
            let away = distance(from: point, to: frame)
            if away <= reach, away <= nearest?.distance ?? .infinity {
                nearest = (index, away)
            }
        }
        return nearest?.index
    }

    /// From `point` to the frame as it is drawn: zero inside it.
    private func distance(from point: CGPoint, to frame: CGRect) -> CGFloat {
        let origin = self.point(fromBoard: frame.origin)
        let dx = max(origin.x - point.x, point.x - (origin.x + frame.width * scale), 0)
        let dy = max(origin.y - point.y, point.y - (origin.y + frame.height * scale), 0)
        return (dx * dx + dy * dy).squareRoot()
    }
}

#Preview {
    let container = PreviewNotes.container(seeded: true)
    let board = PreviewNotes.boards(in: container)[0]
    BoardOverview(notes: (board.notes ?? []).sorted { $0.z < $1.z }) { _ in }
        .previewNotes(container)
}
