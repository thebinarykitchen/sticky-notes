import AccessibilityIdentifiers
import SwiftUI

/// The bottom of the list of boards: version, support and privacy policy. App Review looks for all
/// three, and `PreflightTests` checks they are there.
struct AboutSection: View {
    var body: some View {
        Section {
            LabeledContent {
                Text(verbatim: AppInfo.version).foregroundStyle(.primary)
            } label: {
                Text("Version", comment: "In the list of boards, beside the app's version.")
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(A11y.About.versionRow)

            Link(destination: AppInfo.support) {
                Text("Support", comment: "In the list of boards: opens the support page.")
            }
            .accessibilityIdentifier(A11y.About.supportLink)

            Link(destination: AppInfo.privacyPolicy) {
                Text(
                    "Privacy Policy",
                    comment: "In the list of boards: opens the privacy policy.")
            }
            .accessibilityIdentifier(A11y.About.privacyLink)
        } header: {
            // The system's gray falls short of the audit's contrast at this size.
            Text("About", comment: "The heading over the version, support and privacy policy.")
                .foregroundStyle(Color.primary)
        }
    }
}

/// The app's version and external URLs.
enum AppInfo {
    /// Must match the Support URL in App Store Connect.
    static let support = URL(string: "https://www.thebinarykitchen.com/contact-us/")!

    /// Must match the Privacy Policy URL in App Store Connect.
    static let privacyPolicy = URL(string: "https://www.thebinarykitchen.com/privacy-policy/")!

    /// Marketing version and build, e.g. `1.0.0 (27)`.
    static var version: String {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(marketing) (\(build))"
    }
}

#Preview {
    List {
        AboutSection()
    }
}
