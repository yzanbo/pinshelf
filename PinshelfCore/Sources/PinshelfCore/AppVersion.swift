import Foundation

/// アプリの版の見せ方（Pinshot と同じく、1.0.0 より前は β 版。正式版は 1.0.0）
public enum AppVersion {
    /// β 版か（いちばん上の数が 0）
    public static func isBeta(_ version: String) -> Bool {
        guard let major = version.split(separator: ".").first.flatMap({ Int($0) }) else { return false }
        return major < 1
    }

    /// 設定画面に出す版（β 版なら「（β 版）」を付ける。書き方は Pinshot と同じ「β 版」）
    public static func displayName(_ version: String) -> String {
        isBeta(version) ? "\(version)（β 版）" : version
    }
}
