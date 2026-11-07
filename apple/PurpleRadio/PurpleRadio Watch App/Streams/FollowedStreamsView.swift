import SwiftUI

// Placeholder until the followed streams list lands (#20). Sign-out (#19) lives here
// for now.
struct FollowedStreamsView: View {
    let onSignOut: () async -> Void
    @State private var confirmingSignOut = false

    var body: some View {
        NavigationStack {
            Text("No live channels")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") {
                            confirmingSignOut = true
                        }
                    }
                }
                .confirmationDialog("Sign out of Twitch?", isPresented: $confirmingSignOut) {
                    Button("Sign Out", role: .destructive) {
                        Task { await onSignOut() }
                    }
                }
        }
    }
}
