import Foundation
import Testing
@testable import PurpleRadio_Watch_App

struct TwitchAuthClientTests {
    let transport = FakeTransport()
    let start = Date(timeIntervalSince1970: 1_000_000)

    var client: TwitchAuthClient {
        TwitchAuthClient(clientID: "client", transport: transport, now: { [start] in start })
    }

    @Test func startsDeviceAuthorizationWithScopes() async throws {
        await transport.enqueue("/oauth2/device", status: 200, body: """
            {"device_code":"dev","expires_in":1800,"interval":5,"user_code":"ABCD-EFGH",
             "verification_uri":"https://www.twitch.tv/activate?public=true&device-code=ABCDEFGH"}
            """)
        let authorization = try await client.startDeviceAuthorization()
        #expect(authorization.deviceCode == "dev")
        #expect(authorization.userCode == "ABCD-EFGH")
        #expect(authorization.expiresAt == start.addingTimeInterval(1800))
        #expect(authorization.pollInterval == .seconds(5))
        #expect(await transport.lastForm("/oauth2/device") == ["client_id": "client", "scopes": "user:read:follows"])
    }

    @Test func pollReportsPendingAndAuthorized() async throws {
        await transport.enqueue("/oauth2/token", status: 400, body: #"{"status":400,"message":"authorization_pending"}"#)
        await transport.enqueue("/oauth2/token", status: 200, body: """
            {"access_token":"a","refresh_token":"r","expires_in":14400,"scope":["user:read:follows"],"token_type":"bearer"}
            """)
        #expect(try await client.pollDeviceToken(.sample()) == .pending)
        let expected = TwitchCredentials(
            accessToken: "a", refreshToken: "r", expiresAt: start.addingTimeInterval(14400), scopes: ["user:read:follows"]
        )
        #expect(try await client.pollDeviceToken(.sample()) == .authorized(expected))
        let form = await transport.lastForm("/oauth2/token")
        #expect(form["grant_type"] == "urn:ietf:params:oauth:grant-type:device_code")
        #expect(form["device_code"] == "device-1")
        #expect(form["client_secret"] == nil)
    }

    @Test func pollTreatsInvalidDeviceCodeAsExpired() async throws {
        await transport.enqueue("/oauth2/token", status: 400, body: #"{"status":400,"message":"invalid device code"}"#)
        #expect(try await client.pollDeviceToken(.sample()) == .expired)
    }

    @Test func pollTreatsUnknownErrorAfterExpiryAsExpired() async throws {
        await transport.enqueue("/oauth2/token", status: 400, body: #"{"status":400,"message":"something else"}"#)
        let expired = DeviceAuthorization(
            deviceCode: "d", userCode: "u", verificationURL: URL(string: "https://twitch.tv/activate")!,
            expiresAt: start, pollInterval: .seconds(5)
        )
        #expect(try await client.pollDeviceToken(expired) == .expired)
    }

    @Test func pollFailsOnUnknownErrorBeforeExpiry() async throws {
        await transport.enqueue("/oauth2/token", status: 400, body: #"{"status":400,"message":"something else"}"#)
        let authorization = DeviceAuthorization(
            deviceCode: "d", userCode: "u", verificationURL: URL(string: "https://twitch.tv/activate")!,
            expiresAt: start.addingTimeInterval(60), pollInterval: .seconds(5)
        )
        await #expect(throws: TwitchAuthError.deviceAuthorizationFailed) {
            try await client.pollDeviceToken(authorization)
        }
    }

    @Test func refreshSendsRefreshTokenWithoutSecret() async throws {
        await transport.enqueue("/oauth2/token", status: 200, body: """
            {"access_token":"a2","refresh_token":"r2","expires_in":14400,"scope":["user:read:follows"],"token_type":"bearer"}
            """)
        let renewed = try await client.refresh(.sample())
        #expect(renewed.refreshToken == "r2")
        let form = await transport.lastForm("/oauth2/token")
        #expect(form == ["client_id": "client", "grant_type": "refresh_token", "refresh_token": "refresh-1"])
    }

    @Test func refreshRejectionIsInvalidRefreshToken() async {
        await transport.enqueue("/oauth2/token", status: 400, body: #"{"status":400,"message":"Invalid refresh token"}"#)
        await #expect(throws: TwitchAuthError.invalidRefreshToken) {
            try await client.refresh(.sample())
        }
    }

    @Test func validateUsesOAuthHeader() async throws {
        await transport.enqueue("/oauth2/validate", status: 200)
        await transport.enqueue("/oauth2/validate", status: 401)
        #expect(try await client.validate(accessToken: "tok"))
        #expect(try await !client.validate(accessToken: "tok"))
        let request = await transport.requests.last!
        #expect(request.value(forHTTPHeaderField: "Authorization") == "OAuth tok")
    }

    @Test func formEncodingEscapesReservedCharacters() {
        let body = String(data: TwitchAuthClient.formEncode(["a": "x y:z/&="]), encoding: .utf8)
        #expect(body == "a=x%20y%3Az%2F%26%3D")
    }

    @Test func deviceAuthorizationDescriptionIsRedacted() {
        let authorization = DeviceAuthorization.sample("secret")
        for text in ["\(authorization)", String(reflecting: authorization)] {
            #expect(!text.contains("secret"))
        }
    }
}
