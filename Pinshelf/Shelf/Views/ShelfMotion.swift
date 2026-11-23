import AppKit
import SwiftUI

/// 棚の動きの決まり（ウィンドウの枠のアニメーションと、SwiftUI の中身のアニメーションをそろえる）
///
/// macOS の「視差効果を減らす」がオンなら、短いフェードだけにする。
enum ShelfMotion {
    /// 「視差効果を減らす」がオンか
    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// 帯と棚の切り替え・出入りの長さ（秒）
    static var duration: TimeInterval {
        reduceMotion ? 0.12 : 0.24
    }

    // MARK: - ふつうの動き（開く・出す・しまう・浮かせる）

    /// 出だしは速く、止まり際はゆっくり（引き出しが止まるような動き）
    private static let standardCurve = Curve(x1: 0.2, y1: 0.9, x2: 0.25, y2: 1.0)

    /// ウィンドウの枠のアニメーションの速さの変わり方
    static var timingFunction: CAMediaTimingFunction {
        reduceMotion ? CAMediaTimingFunction(name: .easeOut) : standardCurve.timingFunction
    }

    /// 中身（SwiftUI）のアニメーション。ウィンドウの枠と同じ長さ・同じ速さの変わり方にする
    static var animation: Animation {
        reduceMotion ? .easeOut(duration: duration) : standardCurve.animation(duration: duration)
    }

    // MARK: - 帯にたたむとき

    /// すぐに動き出し、少しだけ勢いをつけてから、画面の端に向かってなめらかに止まる。
    ///
    /// ふつうの動き（standardCurve）と同じにすると、はじめの 2 コマほどで半分以上縮み、棚が一瞬で消えたように見える。
    /// 開くときを逆に再生すると、長く動かないあと、最後の一瞬で一気にしまわれる。どちらも不自然なので、たたむとき用に分ける
    private static let foldCurve = Curve(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1.0)

    /// 帯にたたむときの、ウィンドウの枠のアニメーションの速さの変わり方
    static var foldTimingFunction: CAMediaTimingFunction {
        reduceMotion ? CAMediaTimingFunction(name: .easeOut) : foldCurve.timingFunction
    }

    /// 帯にたたむときの、棚と帯の入れ替わり（透明度）のアニメーション。
    /// 棚は、端へ滑り込んでいる間は見えたままにし、端に近づくにつれて帯に入れ替える
    /// （枠と同じ速さで消すと、滑り込む動きが見える前に棚が消えてしまう）
    static var foldFadeAnimation: Animation {
        reduceMotion ? .easeOut(duration: duration) : .easeInOut(duration: duration)
    }

    // MARK: - 出入り

    /// 浮いた棚が出るときの、はじめの大きさ（1 が実物大）
    static var appearScale: CGFloat {
        reduceMotion ? 1 : 0.94
    }

    /// 画面端の棚が画面の外から滑り込むときの、はじめのずれ（pt）
    static var slideDistance: CGFloat {
        reduceMotion ? 0 : 28
    }

    // MARK: - 速さの変わり方

    /// 速さの変わり方（3 次ベジェ曲線の 2 つの制御点。ウィンドウの枠と SwiftUI の両方で同じものを使う）
    private struct Curve {
        let x1: Float
        let y1: Float
        let x2: Float
        let y2: Float

        /// ウィンドウの枠のアニメーション用
        var timingFunction: CAMediaTimingFunction {
            CAMediaTimingFunction(controlPoints: x1, y1, x2, y2)
        }

        /// SwiftUI のアニメーション用
        func animation(duration: TimeInterval) -> Animation {
            .timingCurve(Double(x1), Double(y1), Double(x2), Double(y2), duration: duration)
        }
    }
}
