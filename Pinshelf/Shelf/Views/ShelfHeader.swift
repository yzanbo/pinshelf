import PinshelfCore
import SwiftUI

/// 棚の見出し: 閉じる・しまうのボタン、名前（なければ件数）、元に戻す・メニュー・ピン・帯にたたむボタン
///
/// 上の帯をつかんで棚を動かせる。ダブルクリックでしまう・浮かせる。名前を変えるときは、ここで入力する。
struct ShelfHeader: View {
    let model: ShelfModel
    let state: ShelfState
    let actions: ShelfActions
    @State private var draftName = ""
    @FocusState private var isNameFocused: Bool
    /// 左右のボタン欄の幅（名前を、ボタンにかからないように置くため）
    @State private var leadingButtonsWidth: CGFloat = 0
    @State private var trailingButtonsWidth: CGFloat = 0

    var body: some View {
        // 左右のボタン欄は中身の幅だけにする（決まった幅で取ると、狭い棚で名前の欄が足りなくなる）
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                Button(action: actions.close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 18)
                        .background(.quaternary, in: Circle())
                }
                .buttonStyle(.plain)
                .help(state.isFavorite ? "隠す（メニューバーの「お気に入りの棚」から出し直せます）" : "閉じる（メニューバーの「最近閉じた棚」から開き直せます）")

                Button(action: actions.toggleDock) {
                    Image(systemName: state.isDocked ? "macwindow" : "sidebar.right")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .help(state.isDocked ? "浮かせる（見出しをつかんで真ん中へ運ぶ・ダブルクリックでも）" : "画面の端にしまう（画面の端まで運ぶ・見出しのダブルクリックでも）")
            }
            .fixedSize()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { leadingButtonsWidth = $0 }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                // 元に戻せるときは「元に戻す」
                if model.undoCount > 0 {
                    UndoButton(model: model)
                }
                Menu {
                    ShelfMenu(state: state, actions: actions)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("棚のメニュー（名前・色・お気に入り・大きさ）")
                // 画面の端にある棚は、開いたままにするピンと、帯にたたむボタン（画面の端の向きの矢印）
                if let edge = state.dockedEdge {
                    Button(action: actions.toggleKeepsOpen) {
                        Image(systemName: state.keepsOpen ? "pin.fill" : "pin")
                            .font(.system(size: 11))
                            .foregroundStyle(state.keepsOpen ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(state.keepsOpen
                        ? "開いたままにしています（押すと、ポインタが離れたら帯にたたむようになります）"
                        : "開いたままにする（いまは、ポインタが離れると帯にたたみます）")
                    Button(action: actions.fold) {
                        Image(systemName: edge == .right ? "chevron.right" : "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .help("帯にたたむ")
                }
            }
            .fixedSize()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { trailingButtonsWidth = $0 }
        }
        // 名前（なければ件数）は 1 行で置く（折り返さない）
        .overlay {
            if state.isRenaming {
                titleBetweenButtons
            } else {
                ViewThatFits(in: .horizontal) {
                    // 入るなら、棚の真ん中に置く（左右のボタンの広いほうの幅だけよける）
                    title
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, max(leadingButtonsWidth, trailingButtonsWidth) + 6)
                    // 入らないときは、左右のボタンのあいだを全部使う（それでも入らなければ「…」で省く）
                    titleBetweenButtons
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .contentShape(Rectangle())
        // 上の帯をつかんで棚を動かせる（画面の端まで運ぶとしまう）。ダブルクリックでしまう・浮かせる
        .gesture(WindowDragGesture())
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            if !state.isRenaming { actions.toggleDock() }
        })
        .allowsWindowActivationEvents(true)
        .contextMenu { ShelfMenu(state: state, actions: actions) }
    }

    /// 左右のボタンのあいだに置いた名前
    private var titleBetweenButtons: some View {
        title
            .padding(.leading, leadingButtonsWidth + 6)
            .padding(.trailing, trailingButtonsWidth + 6)
    }

    /// 名前（なければ件数）・色の点・★の印。名前を変えるときは、ここで入力する
    @ViewBuilder
    private var title: some View {
        if state.isRenaming {
            TextField("棚の名前", text: $draftName)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .frame(maxWidth: 140)
                .focused($isNameFocused)
                .onSubmit { actions.commitRename(draftName) }
                .onExitCommand { actions.cancelRename() }
                .onAppear {
                    draftName = state.name ?? ""
                    isNameFocused = true
                }
                // ほかのところを押したら、入力したところまでで決める
                .onChange(of: isNameFocused) { _, focused in
                    if !focused, state.isRenaming { actions.commitRename(draftName) }
                }
        } else {
            HStack(spacing: 4) {
                if let color = state.color.color {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                if let name = state.name {
                    // 狭いときは名前のほうを「…」で省き、件数は省かない
                    Text(name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("\(model.items.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .fixedSize()
                } else {
                    Text(model.countLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if state.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.yellow)
                        .help("お気に入り（閉じても残ります）")
                }
            }
        }
    }
}

/// 「元に戻す」ボタン（最後に棚から外したものを戻す）
struct UndoButton: View {
    let model: ShelfModel

    var body: some View {
        Button {
            model.undoRemoval()
        } label: {
            Image(systemName: "arrow.uturn.backward")
        }
        .buttonStyle(.borderless)
        .help("外したものを戻す（⌘Z）")
    }
}
