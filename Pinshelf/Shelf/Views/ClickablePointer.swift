import SwiftUI

extension View {
    /// 押せるところ（棚の見出し・中身のボタン）: ポインタを乗せたら、指の形にする
    ///
    /// macOS は、前面にないアプリがポインタの形を変えるのを許さないため、棚がキーウィンドウのとき（一度押したあと）に効く
    func clickablePointer() -> some View {
        pointerStyle(.link)
    }
}
