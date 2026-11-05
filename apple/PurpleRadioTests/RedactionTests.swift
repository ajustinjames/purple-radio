import Foundation
import Testing
@testable import PurpleRadio

struct RedactionTests {
    @Test func credentialDescriptionsHideTokens() {
        let credentials = TwitchCredentials(
            accessToken: "access-secret",
            refreshToken: "refresh-secret",
            expiresAt: .distantFuture,
            scopes: ["user:read:follows"]
        )
        for text in ["\(credentials)", String(describing: credentials), String(reflecting: credentials)] {
            #expect(!text.contains("secret"))
        }
    }

    @Test func redactedErrorKeepsOnlyDomainAndCode() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorBadServerResponse,
            userInfo: [NSLocalizedDescriptionKey: "https://example.com/signed?sig=secret"]
        )
        #expect(Log.redacted(error) == "\(NSURLErrorDomain) \(NSURLErrorBadServerResponse)")
    }
}
