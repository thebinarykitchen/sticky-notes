import SwiftUI

extension View {
    /// Puts the tour up when ``OnboardingProgress`` says it is due — on a first launch, and when
    /// it is asked for again — in one window only. On a window's root.
    func stagesTheTour() -> some View {
        modifier(StagesTheTour())
    }
}

/// See ``SwiftUI/View/stagesTheTour()``.
private struct StagesTheTour: ViewModifier {
    @Environment(TourStage.self) private var stage
    @Environment(\.appearsActive) private var appearsActive
    @State private var isShowing = false
    /// This window, for ``TourStage``.
    @State private var window = UUID()

    private var tour = OnboardingProgress()

    func body(content: Content) -> some View {
        content
            // On first launch and after `markDue()`, in one window only: the active one, or the
            // first of several active ones to ask.
            .onChange(of: tour.isDue, initial: true) { stageTheTour() }
            .onChange(of: appearsActive) { stageTheTour() }
            .onChange(of: stage.presenter) { stageTheTour() }
            .onDisappear { stage.release(from: window) }
            .tourCover(isPresented: $isShowing, size: OnboardingView.macSize) {
                OnboardingView()
            }
    }

    /// Puts the due tour up here if this window is active and may take it. Once it is no longer
    /// due — finished or skipped in whichever window had it — hands the stage back.
    private func stageTheTour() {
        guard tour.isDue else {
            stage.release(from: window)
            return
        }
        guard appearsActive, stage.claim(for: window) else { return }
        isShowing = true
    }
}
