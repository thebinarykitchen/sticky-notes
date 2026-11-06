import SwiftUI

/// What the reader works a board with. With ``SwiftUI/View/tourCover(isPresented:size:content:)``,
/// the one place a platform is named: a view asks these rather than writing `#if os` itself.
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
    /// Puts the tour up: over the whole window on iPhone and iPad, and on the Mac as a sheet of
    /// `size`. A sheet there is as big as what is in it, and pages that measure differently would
    /// resize it on the way through.
    func tourCover<Content: View>(
        isPresented: Binding<Bool>, size: CGSize, @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(macOS)
            sheet(isPresented: isPresented) {
                content().frame(width: size.width, height: size.height)
            }
        #else
            fullScreenCover(isPresented: isPresented, content: content)
        #endif
    }
}
