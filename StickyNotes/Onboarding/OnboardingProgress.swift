import AppTour
import LaunchArguments
import SwiftUI

extension TourProgress {
    /// Bump only when existing readers should see the tour again.
    static let version = 1

    /// Whether the tour should be up. Named by the case the UI tests preset it through.
    static var app: TourProgress {
        TourProgress(key: LaunchDefault.onboardingFinished.rawValue, version: version)
    }
}

/// Which lessons the reader knows, so a gesture the tour was skipped past — or pressed through —
/// is hinted on a real board instead.
struct OnboardingProgress: DynamicProperty {
    /// A `var`, as a `DynamicProperty` is everywhere, so SwiftUI installs its `@AppStorage`.
    private var tour = TourProgress.app
    /// Comma-separated ``Lesson`` raw values: done, on the tour or a board, or whose hint was
    /// dismissed. Named by the case the UI tests preset it through.
    @AppStorage(LaunchDefault.onboardingKnown.rawValue) private var knownList = ""

    var known: Set<Lesson> { Self.lessons(in: knownList) }

    /// Called when the lesson's gesture is done anywhere, or its hint is dismissed.
    func learn(_ lesson: Lesson) {
        let known = known
        guard !known.contains(lesson) else { return }
        knownList = Self.list(of: known.union([lesson]))
    }

    /// The lesson to hint on a board of `notes` notes; nil while the tour itself is due.
    func hint(notes: Int) -> Lesson? {
        tour.isDue ? nil : Self.hint(known: known, notes: notes)
    }

    /// The first lesson in teaching order not yet known that a board this full can be shown, so
    /// only one hint is ever up.
    static func hint(known: Set<Lesson>, notes: Int) -> Lesson? {
        Lesson.allCases.first { !known.contains($0) && notes >= $0.hintedFrom }
    }

    /// Unknown raw values are dropped, so a lesson retired later reads as nothing.
    static func lessons(in list: String) -> Set<Lesson> {
        Set(list.split(separator: ",").compactMap { Lesson(rawValue: String($0)) })
    }

    /// In case order, so the stored value doesn't depend on set order.
    static func list(of lessons: Set<Lesson>) -> String {
        Lesson.allCases.filter(lessons.contains).map(\.rawValue).joined(separator: ",")
    }
}
