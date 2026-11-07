import SwiftUI

/// QR sign-in (#19). `model` is `nil` when no Twitch client ID is configured.
struct SignInView: View {
    let model: SignInModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    content(model)
                        .task(id: model.attempt) { await model.run() }
                } else {
                    ContentUnavailableView(
                        "Sign-in isn't configured",
                        systemImage: "key.slash",
                        description: Text("Set TWITCH_CLIENT_ID in Local.xcconfig. See apple/README.md.")
                    )
                }
            }
            .navigationTitle("Sign In")
        }
    }

    @ViewBuilder
    private func content(_ model: SignInModel) -> some View {
        switch model.state {
        case .requestingCode:
            ProgressView()
        case .awaitingApproval(let authorization, let qrCode):
            ScrollView {
                VStack(spacing: 6) {
                    Text("Scan to sign in")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    QRCodeView(code: qrCode)
                        .frame(maxWidth: 120)
                    Text(authorization.userCode)
                        .font(.title3.monospaced().weight(.semibold))
                        .accessibilityLabel("Code \(authorization.userCode)")
                    Text(Self.displayAddress(authorization.verificationURL))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        case .failed:
            ContentUnavailableView {
                Label("Couldn't start sign-in", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button("Try Again") { model.retry() }
            }
        }
    }

    /// The activation page without the scheme, `www.` or query, which holds the device
    /// code: "twitch.tv/activate".
    static func displayAddress(_ url: URL) -> String {
        var host = url.host() ?? ""
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host + url.path()
    }
}

#Preview("Not configured") {
    SignInView(model: nil)
}
