import Foundation

/// A pending device code sign-in: what the watch shows while the listener approves.
nonisolated struct DeviceAuthorization: Equatable, Sendable {
    /// Identifies this sign-in when polling. Secret: never log it.
    let deviceCode: String
    /// The short code the listener can type at the verification URL.
    let userCode: String
    /// Twitch's activation page. It includes the device code, so it's secret too.
    let verificationURL: URL
    let expiresAt: Date
    /// How long to wait between polls.
    let pollInterval: Duration
}

nonisolated extension DeviceAuthorization: CustomStringConvertible, CustomDebugStringConvertible {
    var description: String { "DeviceAuthorization(redacted)" }
    var debugDescription: String { description }
}

/// The outcome of one poll of a device code sign-in.
nonisolated enum DeviceTokenPoll: Equatable, Sendable {
    case pending
    /// Twitch asked the app to poll less often.
    case slowDown
    /// The code expired before the listener approved it.
    case expired
    case authorized(TwitchCredentials)
}

nonisolated enum TwitchAuthError: Error, Equatable {
    /// Twitch rejected the refresh token: it was used already, expired, or revoked.
    case invalidRefreshToken
    /// Twitch rejected the device code for a reason other than expiry, such as the
    /// listener declining access.
    case deviceAuthorizationFailed
    case unexpectedStatus(Int)
    case malformedResponse
}

/// Twitch's documented OAuth endpoints for a public client.
nonisolated protocol TwitchAuthAPI: Sendable {
    func startDeviceAuthorization() async throws -> DeviceAuthorization
    func pollDeviceToken(_ authorization: DeviceAuthorization) async throws -> DeviceTokenPoll
    func refresh(_ credentials: TwitchCredentials) async throws -> TwitchCredentials
    /// `false` when Twitch reports the access token is no longer valid.
    func validate(accessToken: String) async throws -> Bool
    func revoke(accessToken: String) async throws
}

/// Implements `TwitchAuthAPI` with the device code grant flow:
/// https://dev.twitch.tv/docs/authentication/getting-tokens-oauth/#device-code-grant-flow
///
/// The app is a public client, so no request carries a client secret.
nonisolated struct TwitchAuthClient: TwitchAuthAPI {
    /// The scopes sign-in requests. `user:read:follows` is needed for followed streams.
    static let scopes = ["user:read:follows"]

    let clientID: String
    var transport: any HTTPTransport = URLSession.shared
    var now: @Sendable () -> Date = { Date() }

    private static let base = URL(string: "https://id.twitch.tv/oauth2/")!

    func startDeviceAuthorization() async throws -> DeviceAuthorization {
        let (data, status) = try await post("device", [
            "client_id": clientID,
            "scopes": Self.scopes.joined(separator: " "),
        ])
        guard status == 200 else { throw TwitchAuthError.unexpectedStatus(status) }
        let response = try decode(DeviceResponse.self, from: data)
        guard let url = URL(string: response.verification_uri) else {
            throw TwitchAuthError.malformedResponse
        }
        return DeviceAuthorization(
            deviceCode: response.device_code,
            userCode: response.user_code,
            verificationURL: url,
            expiresAt: now().addingTimeInterval(TimeInterval(response.expires_in)),
            pollInterval: .seconds(max(response.interval, 1))
        )
    }

    func pollDeviceToken(_ authorization: DeviceAuthorization) async throws -> DeviceTokenPoll {
        let (data, status) = try await post("token", [
            "client_id": clientID,
            "scopes": Self.scopes.joined(separator: " "),
            "device_code": authorization.deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
        ])
        if status == 200 {
            return .authorized(try credentials(from: data))
        }
        guard status == 400 else { throw TwitchAuthError.unexpectedStatus(status) }
        // Twitch documents "authorization_pending" and, for a used code, "invalid device
        // code". Its response to an expired code isn't documented, so any other error
        // after the code's expiry time counts as expiry.
        switch errorMessage(in: data) {
        case "authorization_pending": return .pending
        case "slow_down": return .slowDown
        case "invalid device code": return .expired
        default:
            if now() >= authorization.expiresAt { return .expired }
            throw TwitchAuthError.deviceAuthorizationFailed
        }
    }

    func refresh(_ credentials: TwitchCredentials) async throws -> TwitchCredentials {
        let (data, status) = try await post("token", [
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": credentials.refreshToken,
        ])
        switch status {
        case 200: return try self.credentials(from: data)
        case 400, 401: throw TwitchAuthError.invalidRefreshToken
        default: throw TwitchAuthError.unexpectedStatus(status)
        }
    }

    func validate(accessToken: String) async throws -> Bool {
        var request = URLRequest(url: Self.base.appending(path: "validate"))
        request.setValue("OAuth \(accessToken)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await transport.send(request)
        switch response.statusCode {
        case 200: return true
        case 401: return false
        default: throw TwitchAuthError.unexpectedStatus(response.statusCode)
        }
    }

    func revoke(accessToken: String) async throws {
        let (_, status) = try await post("revoke", ["client_id": clientID, "token": accessToken])
        guard status == 200 else { throw TwitchAuthError.unexpectedStatus(status) }
    }

    // MARK: - Requests

    private func post(_ path: String, _ form: [String: String]) async throws -> (Data, Int) {
        var request = URLRequest(url: Self.base.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncode(form)
        let (data, response) = try await transport.send(request)
        return (data, response.statusCode)
    }

    /// Form-encodes fields, percent-encoding everything outside RFC 3986's unreserved
    /// set so values such as space-separated scopes survive.
    static func formEncode(_ form: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let body = form.sorted { $0.key < $1.key }.map { key, value in
            let encoded = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            return "\(key)=\(encoded)"
        }
        return Data(body.joined(separator: "&").utf8)
    }

    private func credentials(from data: Data) throws -> TwitchCredentials {
        let response = try decode(TokenResponse.self, from: data)
        return TwitchCredentials(
            accessToken: response.access_token,
            refreshToken: response.refresh_token,
            expiresAt: now().addingTimeInterval(TimeInterval(response.expires_in)),
            scopes: response.scope ?? []
        )
    }

    private func errorMessage(in data: Data) -> String? {
        (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.message
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw TwitchAuthError.malformedResponse
        }
    }

    // Twitch's field names, decoded as-is.
    private struct DeviceResponse: Decodable {
        let device_code: String
        let user_code: String
        let verification_uri: String
        let expires_in: Int
        let interval: Int
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String
        let expires_in: Int
        let scope: [String]?
    }

    private struct ErrorResponse: Decodable {
        let message: String
    }
}
