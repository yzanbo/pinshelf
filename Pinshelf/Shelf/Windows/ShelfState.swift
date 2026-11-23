import Observation
import PinshelfCore
import SwiftUI

/// 棚の見え方（置き方・名前・色・大きさなど。ShelfView が描く）
@Observable
final class ShelfState {
    enum Placement: Equatable {
        /// 浮いている
        case floating
        /// 画面端にしまっている
        case docked(ScreenEdge)
    }

    var placement: Placement = .floating
    /// しまっているとき、帯ではなく棚を開いているか
    var isUnfolded = false
    /// 棚の名前（なければ件数を出す）
    var name: String?
    /// 棚の色
    var color: ShelfColor = .none
    /// お気に入り（閉じても中身ごと残し、メニューバーから出し直せる）
    var isFavorite = false
    /// 名前を入力しているところか
    var isRenaming = false
    /// 出ているか（出るときに、少し小さい状態から実物大にふわっと広げるため）
    var isPresented = true
    /// 画面端の棚か（ドラッグに合わせて自動で出し入れする棚。浮かせる・閉じると、ただの棚に戻る）
    var isEdgeShelf = false
    /// 画面の端で開いたままにするか（見出しのピン）。false なら、ポインタが離れると細い帯にたたむ
    var keepsOpen = false
    /// 浮いているときの大きさ
    var floatingSize = ShelfSizing.defaultSize(for: .floating)
    /// 画面の端にあるとき（開いたとき）の大きさ
    var dockedSize = ShelfSizing.defaultSize(for: .docked)

    /// 今の置き方での大きさ（縁をつかんで変えると、今の置き方のほうが変わる）
    ///
    /// 置き方ごとに大きさを持つので、画面端にしまうと画面の端にあるときの大きさに、浮かせると浮いているときの大きさに戻る。
    var size: CGSize {
        get { isDocked ? dockedSize : floatingSize }
        set {
            if isDocked {
                dockedSize = newValue
            } else {
                floatingSize = newValue
            }
        }
    }
    /// 縁をつかんで大きさを変えているところか（その間は、棚をウィンドウいっぱいに描く）
    var isResizing = false
    /// ポインタを乗せている・つかんでいる縁（その縁を光らせる）
    var hoveredResizeHandle: ResizeHandle?

    /// しまっている端（浮いていれば nil）
    var dockedEdge: ScreenEdge? {
        if case .docked(let edge) = placement { edge } else { nil }
    }

    var isDocked: Bool {
        if case .docked = placement { true } else { false }
    }

    /// 端の細い帯だけを見せているか
    var isFolded: Bool { isDocked && !isUnfolded }
}
