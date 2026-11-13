import SwiftUI
import AppKit

/// A compact About window in the style of the system's own.
struct ClockAbout: View {
    private let info = Bundle.main.infoDictionary ?? [:]
    private var version: String {
        let short = info["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? "Version \(short)" : "Version \(short) (\(build))"
    }

    /// Read from the bundle, not the Dock's icon cache, so it always matches this build.
    private static let icon: NSImage = Bundle.main.url(forResource: "Clock", withExtension: "icns")
        .flatMap(NSImage.init(contentsOf:)) ?? NSApp.applicationIconImage

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: Self.icon)
                .resizable()
                .frame(width: 128, height: 128)
                .accessibilityHidden(true)
            Text("Type AB1")
                .font(.system(size: 26, weight: .semibold))
            Text(version)
                .font(.callout).foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.top, 2)

            Text("A little square. A yellow second.\nA quieter desktop.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
            Text("A tribute to the AB 1, designed by Dietrich Lubs in 1987, and to a design tradition that knew when to stop.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            Link("Source code", destination: URL(string: "https://github.com/duivesteyn/type-AB1A")!)
                .font(.callout)
                .padding(.top, 14)

            Divider().padding(.top, 20)

            Text("Made by Benjamin Duivesteyn · MIT License\nNo accounts, analytics or network requests.")
                .font(.caption).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
        }
        .padding(.horizontal, 32)
        .padding(.top, 14)
        .padding(.bottom, 24)
        .frame(width: 380)
    }
}
