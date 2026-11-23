import Testing
@testable import PinshelfCore

@Suite("アプリの版")
struct AppVersionTests {
    @Test("1.0.0 より前は β 版として出す")
    func beta() {
        #expect(AppVersion.isBeta("0.1.0"))
        #expect(AppVersion.displayName("0.1.0") == "0.1.0（β 版）")
    }

    @Test("1.0.0 からは正式版（版だけを出す）")
    func release() {
        #expect(!AppVersion.isBeta("1.0.0"))
        #expect(AppVersion.displayName("1.0.0") == "1.0.0")
        #expect(AppVersion.displayName("2.3") == "2.3")
    }

    @Test("読めない版は、そのまま出す")
    func unreadable() {
        #expect(!AppVersion.isBeta("—"))
        #expect(AppVersion.displayName("—") == "—")
    }
}
