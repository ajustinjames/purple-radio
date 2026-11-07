import Testing
@testable import PurpleRadio_Watch_App

@MainActor
struct AppModelTests {
    let auth = FakeAuth()

    @Test func storedCredentialsSkipSignIn() async {
        let model = AppModel(auth: auth, store: InMemoryTokenStore(.sample()))
        #expect(model.phase == .launching)
        let task = Task { await model.start() }
        while model.phase == .launching { await Task.yield() }
        #expect(model.phase == .signedIn)
        #expect(model.signIn == nil)
        task.cancel()
    }

    @Test func noCredentialsShowsSignIn() async {
        let model = AppModel(auth: auth, store: InMemoryTokenStore())
        let task = Task { await model.start() }
        while model.phase == .launching { await Task.yield() }
        #expect(model.phase == .signedOut)
        #expect(model.signIn != nil)
        task.cancel()
    }

    @Test func unconfiguredClientShowsSignInWithoutModel() async {
        let model = AppModel(auth: nil, store: InMemoryTokenStore(.sample()))
        await model.start()
        #expect(model.phase == .signedOut)
        #expect(model.signIn == nil)
    }

    @Test func failedRefreshReturnsToSignIn() async throws {
        let model = AppModel(auth: auth, store: InMemoryTokenStore(.sample(expiresIn: 0)))
        let task = Task { await model.start() }
        while model.phase == .launching { await Task.yield() }
        #expect(model.phase == .signedIn)
        _ = try? await model.session?.accessToken()  // The fake rejects the refresh.
        while model.phase == .signedIn { await Task.yield() }
        #expect(model.phase == .signedOut)
        task.cancel()
    }

    @Test func signOutClearsStoreAndShowsSignIn() async {
        let store = InMemoryTokenStore(.sample())
        let model = AppModel(auth: auth, store: store)
        let task = Task { await model.start() }
        while model.phase == .launching { await Task.yield() }
        await model.signOut()
        #expect(model.phase == .signedOut)
        #expect(await store.stored == nil)
        task.cancel()
    }
}
