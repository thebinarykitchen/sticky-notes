import SwiftUI

/// What the reader works a board with. The one place a platform is named: a view asks these rather
/// than writing `#if os` itself.
nonisolated enum Pointing: Sendable {
    /// Fingers, on iPhone and iPad.
    case touch
    /// A pointer, and maybe a trackpad, on the Mac.
    case pointer

    static var current: Pointing {
        #if os(macOS)
            .pointer
        #else
            .touch
        #endif
    }
}

extension View {
    /// Gives a board's overview a size on the Mac, where a sheet is as big as what is in it and a
    /// map takes whatever it is given. On iPhone and iPad the sheet decides.
    func overviewSheetSize() -> some View {
        #if os(macOS)
            frame(width: 640, height: 520)
        #else
            self
        #endif
    }
}
