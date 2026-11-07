import SwiftUI

struct RootView: View {
    let model: AppModel

    var body: some View {
        Group {
            switch model.phase {
            case .launching:
                ProgressView()
            case .signedOut:
                SignInView(model: model.signIn)
            case .signedIn:
                FollowedStreamsView(onSignOut: { await model.signOut() })
                    .task { await model.validatePeriodically() }
            }
        }
        .task { await model.start() }
    }
}

#Preview {
    RootView(model: AppModel(auth: nil, store: KeychainTokenStore()))
}
