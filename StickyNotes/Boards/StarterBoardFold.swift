import CoreData
import NoteModel
import OSLog
import SwiftUI

extension View {
    /// Folds the starter boards a sync leaves behind into one, whenever the window becomes active
    /// or an import lands while it is. See ``NoteStore/foldStarterBoards()``.
    ///
    /// Coming forward is the main trigger. SwiftData has no supported signal for a finished
    /// import, and a board that arrives while the app is in the background is one the reader
    /// hasn't seen yet either: coming forward is the moment before they look. The Core Data
    /// remote-change notification is a second trigger, for imports while the window is already
    /// in front. The pass fetches only starter boards, so it is cheap enough for the main actor.
    func foldsStarterBoards() -> some View {
        modifier(StarterBoardFold())
    }
}

private struct StarterBoardFold: ViewModifier {
    @Environment(\.scenePhase) private var phase
    @Environment(NoteStore.self) private var store

    func body(content: Content) -> some View {
        content
            .onChange(of: phase, initial: true) {
                guard phase == .active else { return }
                fold()
            }
            // Trailing-debounced, because one import posts many changes in a burst. Harmless if
            // the notification never comes: coming forward still runs the pass.
            .task {
                var pending: Task<Void, Never>?
                let changes = NotificationCenter.default.notifications(
                    named: .NSPersistentStoreRemoteChange)
                for await _ in changes {
                    pending?.cancel()
                    pending = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(500))
                        guard !Task.isCancelled, phase == .active else { return }
                        fold()
                    }
                }
                pending?.cancel()
            }
    }

    private func fold() {
        let folded = store.foldStarterBoards()
        guard folded > 0 else { return }
        // Noteworthy, not an error: it is the design working, and otherwise leaves no trace.
        Logger.fold.notice("Folded \(folded) starter boards from other devices into one")
    }
}

extension Logger {
    fileprivate static let fold = Logger(
        subsystem: "com.thebinarykitchen.Stickies", category: "store")
}
