import Foundation
import Synchronization
@testable import PurpleRadio_Watch_App

/// Records requests and answers each with the next queued response for its path.
actor FakeTransport: HTTPTransport {
    private var responses: [String: [(Int, String)]] = [:]
    private(set) var requests: [URLRequest] = []

    func enqueue(_ path: String, status: Int, body: String = "{}") {
        responses[path, default: []].append((status, body))
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let path = request.url!.path()
        guard var queue = responses[path], !queue.isEmpty else { throw URLError(.notConnectedToInternet) }
        let (status, body) = queue.removeFirst()
        responses[path] = queue
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }

    /// The form fields of the most recent request to `path`.
    func lastForm(_ path: String) -> [String: String] {
        guard let request = requests.last(where: { $0.url!.path() == path }),
              let body = request.httpBody.flatMap({ String(data: $0, encoding: .utf8) }) else { return [:] }
        var fields: [String: String] = [:]
        for pair in body.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            fields[parts[0]] = parts.count > 1 ? parts[1].removingPercentEncoding : ""
        }
        return fields
    }
}

actor InMemoryTokenStore: TokenStore {
    private(set) var stored: TwitchCredentials?
    private(set) var saveCount = 0

    init(_ credentials: TwitchCredentials? = nil) { stored = credentials }

    func load() async throws -> TwitchCredentials? { stored }
    func save(_ credentials: TwitchCredentials) async throws {
        stored = credentials
        saveCount += 1
    }
    func clear() async throws { stored = nil }
}

/// Scripted `TwitchAuthAPI`.
final class FakeAuth: TwitchAuthAPI {
    private struct State {
        var authorizations: [DeviceAuthorization] = []
        var polls: [DeviceTokenPoll] = []
        var refreshResult: Result<TwitchCredentials, TwitchAuthError> = .failure(.invalidRefreshToken)
        var refreshDelay: Duration = .zero
        var validateResult = true
        var refreshCount = 0
        var startCount = 0
        var revoked: [String] = []
    }

    private let state = Mutex(State())

    var refreshCount: Int { state.withLock { $0.refreshCount } }
    var startCount: Int { state.withLock { $0.startCount } }
    var revoked: [String] { state.withLock { $0.revoked } }

    func set(authorizations: [DeviceAuthorization] = [], polls: [DeviceTokenPoll] = []) {
        state.withLock {
            $0.authorizations = authorizations
            $0.polls = polls
        }
    }
    func set(refreshResult: Result<TwitchCredentials, TwitchAuthError>, delay: Duration = .zero) {
        state.withLock {
            $0.refreshResult = refreshResult
            $0.refreshDelay = delay
        }
    }
    func set(validateResult: Bool) { state.withLock { $0.validateResult = validateResult } }

    func startDeviceAuthorization() async throws -> DeviceAuthorization {
        let next: DeviceAuthorization? = state.withLock {
            $0.startCount += 1
            return $0.authorizations.isEmpty ? nil : $0.authorizations.removeFirst()
        }
        guard let next else { throw URLError(.notConnectedToInternet) }
        return next
    }

    func pollDeviceToken(_ authorization: DeviceAuthorization) async throws -> DeviceTokenPoll {
        state.withLock { $0.polls.isEmpty ? .pending : $0.polls.removeFirst() }
    }

    func refresh(_ credentials: TwitchCredentials) async throws -> TwitchCredentials {
        let (result, delay) = state.withLock {
            $0.refreshCount += 1
            return ($0.refreshResult, $0.refreshDelay)
        }
        if delay > .zero { try await Task.sleep(for: delay) }
        return try result.get()
    }

    func validate(accessToken: String) async throws -> Bool { state.withLock { $0.validateResult } }
    func revoke(accessToken: String) async throws { state.withLock { $0.revoked.append(accessToken) } }
}

extension TwitchCredentials {
    static func sample(_ suffix: String = "1", expiresIn: TimeInterval = 4 * 60 * 60) -> TwitchCredentials {
        TwitchCredentials(
            accessToken: "access-\(suffix)",
            refreshToken: "refresh-\(suffix)",
            expiresAt: Date().addingTimeInterval(expiresIn),
            scopes: ["user:read:follows"]
        )
    }
}

extension DeviceAuthorization {
    static func sample(_ suffix: String = "1", expiresIn: TimeInterval = 1800) -> DeviceAuthorization {
        DeviceAuthorization(
            deviceCode: "device-\(suffix)",
            userCode: "CODE-\(suffix)",
            verificationURL: URL(string: "https://www.twitch.tv/activate?public=true&device-code=\(suffix)")!,
            expiresAt: Date().addingTimeInterval(expiresIn),
            pollInterval: .seconds(5)
        )
    }
}
