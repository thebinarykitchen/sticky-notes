import AccessibilityIdentifiers
import AppUI
import SwiftUI

/// The bottom of the list of boards, shared from AppUI: version, support and privacy policy. App
/// Review looks for all three, and `PreflightTests` checks they are there.
struct AboutSection: View {
    var body: some View {
        AboutSettingsSection(
            support: AppInfo.support,
            privacyPolicy: AppInfo.privacyPolicy,
            identifiers: AboutSettingsIdentifiers(
                versionRow: A11y.About.versionRow,
                supportLink: A11y.About.supportLink,
                privacyLink: A11y.About.privacyLink
            )
        )
    }
}

/// The app's external URLs.
enum AppInfo {
    /// Must match the Support URL in App Store Connect.
    static let support = URL(string: "https://www.thebinarykitchen.com/contact-us/")!

    /// Must match the Privacy Policy URL in App Store Connect.
    static let privacyPolicy = URL(string: "https://www.thebinarykitchen.com/privacy-policy/")!
}

#Preview {
    List {
        AboutSection()
    }
}
