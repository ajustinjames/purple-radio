import Foundation
import Testing
@testable import PurpleRadio_Watch_App

struct TwitchSessionTests {
    let auth = FakeAuth()

    @Test func returnsStoredTokenWhileFresh() async throws {
        let session = TwitchSession(auth: auth, store: InMemoryTokenStore(.sample()))
        #expect(await session.restore())
        #expect(try await session.accessToken() == "access-1")
        #expect(auth.refreshCount == 0)
    }

    @Test func refreshesNearExpiryAndSavesNewRefreshToken() async throws {
        let store = InMemoryTokenStore(.sample(expiresIn: 60))
        auth.set(refreshResult: .success(.sample("2")))
        let session = TwitchSession(auth: auth, store: store)
        _ = await session.restore()
        #expect(try await session.accessToken() == "access-2")
        #expect(await store.stored?.refreshToken == "refresh-2")
    }

    @Test func concurrentCallersShareOneRefresh() async throws {
        auth.set(refreshResult: .success(.sample("2")), delay: .milliseconds(50))
        let session = TwitchSession(auth: auth, store: InMemoryTokenStore(.sample(expiresIn: 0)))
        _ = await session.restore()
        async let first = session.accessToken()
        async let second = session.accessToken()
        async let third = session.accessToken(replacing: "access-1")
        #expect(try await [first, second, third] == ["access-2", "access-2", "access-2"])
        #expect(auth.refreshCount == 1)
    }

    @Test func rejectedTokenAlreadyReplacedIsNotRefreshedAgain() async throws {
        let session = TwitchSession(auth: auth, store: InMemoryTokenStore(.sample("2")))
        _ = await session.restore()
        #expect(try await session.accessToken(replacing: "access-1") == "access-2")
        #expect(auth.refreshCount == 0)
    }

    @Test func rejectedRefreshEndsSession() async throws {
        let store = InMemoryTokenStore(.sample(expiresIn: 0))
        let session = TwitchSession(auth: auth, store: store)
        _ = await session.restore()
        await #expect(throws: TwitchSession.SessionError.signedOut) {
            try await session.accessToken()
        }
        #expect(await store.stored == nil)
        var ended = session.ended.makeAsyncIterator()
        #expect(await ended.next() != nil)
    }

    @Test func networkFailureDuringRefreshKeepsSession() async throws {
        let store = InMemoryTokenStore(.sample(expiresIn: 0))
        auth.set(refreshResult: .failure(.unexpectedStatus(503)))
        let session = TwitchSession(auth: auth, store: store)
        _ = await session.restore()
        await #expect(throws: TwitchAuthError.unexpectedStatus(503)) {
            try await session.accessToken()
        }
        #expect(await store.stored != nil)
    }

    @Test func invalidTokenOnValidationIsRefreshed() async throws {
        auth.set(validateResult: false)
        auth.set(refreshResult: .success(.sample("2")))
        let session = TwitchSession(auth: auth, store: InMemoryTokenStore(.sample()))
        _ = await session.restore()
        await session.validate()
        #expect(try await session.accessToken() == "access-2")
    }

    @Test func signOutClearsAndRevokes() async throws {
        let store = InMemoryTokenStore(.sample())
        let session = TwitchSession(auth: auth, store: store)
        _ = await session.restore()
        await session.signOut()
        #expect(await store.stored == nil)
        #expect(auth.revoked == ["access-1"])
        await #expect(throws: TwitchSession.SessionError.signedOut) {
            try await session.accessToken()
        }
    }
}
