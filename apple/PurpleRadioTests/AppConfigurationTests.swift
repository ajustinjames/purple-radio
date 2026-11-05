import Testing
@testable import PurpleRadio

struct AppConfigurationTests {
    @Test func readsTwitchClientID() {
        let configuration = AppConfiguration(infoDictionary: ["TwitchClientID": "abc123"])
        #expect(configuration.twitchClientID == "abc123")
    }

    @Test(arguments: [[:], ["TwitchClientID": ""]] as [[String: String]])
    func treatsMissingOrEmptyClientIDAsUnset(info: [String: String]) {
        #expect(AppConfiguration(infoDictionary: info).twitchClientID == nil)
    }
}
