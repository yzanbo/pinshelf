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

    /// 出だしは速く、止まり際はゆっくり（引き出しが止まるような動き）
    private static let curve: (Float, Float, Float, Float) = (0.2, 0.9, 0.25, 1.0)

    /// ウィンドウの枠のアニメーションの速さの変わり方
    static var timingFunction: CAMediaTimingFunction {
        reduceMotion
            ? CAMediaTimingFunction(name: .easeOut)
            : CAMediaTimingFunction(controlPoints: curve.0, curve.1, curve.2, curve.3)
    }

    /// 中身（SwiftUI）のアニメーション。ウィンドウの枠と同じ長さ・同じ速さの変わり方にする
    static var animation: Animation {
        reduceMotion
            ? .easeOut(duration: duration)
            : .timingCurve(Double(curve.0), Double(curve.1), Double(curve.2), Double(curve.3), duration: duration)
    }

    /// 浮いた棚が出るときの、はじめの大きさ（1 が実物大）
    static var appearScale: CGFloat {
        reduceMotion ? 1 : 0.94
    }

    /// 画面端の棚が画面の外から滑り込むときの、はじめのずれ（pt）
    static var slideDistance: CGFloat {
        reduceMotion ? 0 : 28
    }
}
