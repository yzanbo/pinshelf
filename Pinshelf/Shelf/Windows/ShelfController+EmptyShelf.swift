import AppKit
import PinshelfCore

/// 空（0 個）になった棚を閉じる（設定の「棚」→「空になった棚」。画面の端にある棚・浮いた棚で別々に決める）
///
/// ポインタが棚の上にあるうちは閉じず、離れたら閉じる（そのあいだに ⌘Z で戻せるように）。
/// もう離れている・帯にたたんでいるなら、すぐに閉じる。お気に入りの棚は、空になっても残す。
extension ShelfController {
    /// 空になったので閉じる棚か（落としたものを読み込んでいる途中は、空に見えても閉じない）
    var closesWhenEmpty: Bool {
        guard model.isEmpty, model.isSettled, !state.isFavorite else { return false }
        return ShelfBehaviorSettings(defaults: .standard).closesEmptyShelf(docked: state.isDocked)
    }

    /// 中身が変わった: 空になったら閉じる
    ///
    /// 帯にたたむときに閉じる処理（foldOrClose）だけでは、次のときに閉じられない:
    /// - ほかのアプリへ取り出した: 棚から外れるのは、受け取る側が移し終えたあと（ポインタが離れて、帯にたたんだあと）になる
    /// - 開いたままにしている画面の端の棚・浮いた棚: ポインタが離れても、帯にたたまない
    func contentsDidChange() {
        guard closesWhenEmpty, !isHidden, !isUnfoldedByDrag else { return }
        if isOpen, panel.frame.contains(NSEvent.mouseLocation) {
            // 離れる前に中身が戻ったら（⌘Z・落とした）、見張りをやめる
            watchPointer(while: { $0.closesWhenEmpty && $0.isOpen }, onLeave: { $0.close() })
        } else {
            close()
        }
    }

    /// 棚が開いて見えているか（浮いている・画面の端で開いている）
    private var isOpen: Bool {
        state.isDocked ? isOpenOnEdge : panel.isVisible
    }
}
