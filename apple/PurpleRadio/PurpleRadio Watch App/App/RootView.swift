import SwiftUI

struct RootView: View {
    let model: AppModel

    var body: some View {
        switch model.phase {
        case .signedOut:
            SignInView()
        case .signedIn:
            FollowedStreamsView()
        }
    }
}

#Preview {
    RootView(model: AppModel())
}
