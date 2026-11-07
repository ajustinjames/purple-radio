import Foundation
import Testing
@testable import PurpleRadio_Watch_App

@MainActor
struct SignInModelTests {
    let auth = FakeAuth()
    let store = InMemoryTokenStore()

    func makeModel(onSignedIn: @escaping @MainActor () -> Void = {}) -> SignInModel {
        SignInModel(
            auth: auth,
            session: TwitchSession(auth: auth, store: store),
            onSignedIn: onSignedIn,
            sleep: { _ in
                try Task.checkCancellation()
                await Task.yield()
            }
        )
    }

    @Test func approvalSavesCredentialsAndSignsIn() async {
        auth.set(authorizations: [.sample()], polls: [.pending, .pending, .authorized(.sample())])
        var signedIn = false
        let model = makeModel { signedIn = true }
        await model.run()
        #expect(signedIn)
        #expect(await store.stored?.accessToken == "access-1")
    }

    @Test func expiredCodeIsReplaced() async {
        auth.set(authorizations: [.sample("1"), .sample("2")], polls: [.expired, .authorized(.sample())])
        var signedIn = false
        let model = makeModel { signedIn = true }
        await model.run()
        #expect(signedIn)
        #expect(auth.startCount == 2)
    }

    @Test func failureToGetCodeShowsRetry() async {
        let model = makeModel()
        await model.run()
        #expect(model.state == .failed)
        model.retry()
        #expect(model.state == .requestingCode)
        #expect(model.attempt == 1)
    }

    @Test func showsCodeWhileAwaitingApproval() async throws {
        auth.set(authorizations: [.sample()])
        let model = makeModel()
        let task = Task { await model.run() }
        while model.state == .requestingCode { await Task.yield() }
        guard case .awaitingApproval(let authorization, let qrCode) = model.state else {
            Issue.record("Expected a code, got \(model.state)")
            return
        }
        #expect(authorization.userCode == "CODE-1")
        #expect(qrCode == (try QRCode(text: authorization.verificationURL.absoluteString)))
        task.cancel()
    }

    @Test func displayAddressDropsSchemeWwwAndQuery() {
        let url = URL(string: "https://www.twitch.tv/activate?public=true&device-code=SECRET")!
        #expect(SignInView.displayAddress(url) == "twitch.tv/activate")
    }
}
