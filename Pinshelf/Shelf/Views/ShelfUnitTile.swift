import AppKit
import PinshelfCore
import SwiftUI

// MARK: - 棚に置いた 1 つ分

/// 棚に置いた 1 つのもの、またはスタック（一緒に置いたもののまとまり）
///
/// - クリックで選ぶ（⌘ で足し引き、⇧ で範囲）。スタックは中身をまとめて選ぶ
/// - 選んでスペースキーで Quick Look
/// - ダブルクリックで開く（テキストとスタックは Quick Look で見る）
struct ShelfUnitTile: View {
    let unit: [ShelfItem]
    let model: ShelfModel
    @State private var isHovering = false

    private var first: ShelfItem { unit[0] }
    private var isStack: Bool { unit.count > 1 }
    private var isSelected: Bool { unit.allSatisfy(model.isSelected) }
    private var isLocked: Bool { unit.allSatisfy(\.isLocked) }

    var body: some View {
        VStack(spacing: 4) {
            icon
                .frame(width: 44, height: 44)
                .overlay(alignment: .bottomLeading) {
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(Color.orange, in: Circle())
                            .offset(x: -4, y: 4)
                            .help("ロック中（取り出しても棚に残ります）")
                    }
                }
            Text(title)
                .font(.caption)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .background(isSelected ? Color.accentColor : .clear, in: .rect(cornerRadius: 4))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .padding(4)
        .background(background, in: .rect(cornerRadius: 8))
        .contentShape(.rect(cornerRadius: 8))
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Button {
                    model.removeItems(withIDs: Set(unit.map(\.id)))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .help(isStack ? "スタックごと棚から外す" : "棚から外す")
            }
        }
        .overlay(alignment: .topLeading) {
            if isHovering, isStack {
                Button {
                    model.unstack(first)
                } label: {
                    Image(systemName: "rectangle.expand.vertical")
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .help("スタックを分ける")
            }
        }
        .onHover { isHovering = $0 }
        // ダブルクリックを待たずに選べるよう、1 回のクリックは同時に受け取る
        .gesture(TapGesture(count: 2).onEnded { openUnit() })
        .simultaneousGesture(TapGesture().onEnded { model.click(first, modifier: Self.currentModifier()) })
        // 取り出しは ShelfDragSource（AppKit のドラッグ）で行う。ここでは枠だけを知らせる（スタックは中身すべてに同じ枠）
        .background {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .named(ShelfDragSource.coordinateSpace))
                Color.clear.preference(
                    key: ShelfTileFramesKey.self,
                    value: Dictionary(uniqueKeysWithValues: unit.map { ($0.id, frame) })
                )
            }
        }
        .contextMenu { menu }
        .help(isStack ? unit.map(\.content.displayName).joined(separator: "\n") : first.content.detail)
    }

    // MARK: - 見た目

    @ViewBuilder
    private var icon: some View {
        if isStack {
            // 重ねたアイコンと件数
            ZStack {
                ForEach(Array(unit.prefix(3).enumerated().reversed()), id: \.element.id) { index, item in
                    ItemIcon(content: item.content)
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(Double(index) * 8 - 8))
                        .offset(x: CGFloat(index) * 3, y: CGFloat(index) * -2)
                        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                }
            }
            .overlay(alignment: .topTrailing) {
                Text("\(unit.count)")
                    .font(.caption2.monospacedDigit().bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.accentColor, in: Capsule())
                    .offset(x: 6, y: -4)
            }
        } else {
            ItemIcon(content: first.content)
        }
    }

    private var title: String {
        isStack ? "\(first.content.displayName) ほか \(unit.count - 1) 個" : first.content.displayName
    }

    private var background: Color {
        if isSelected { return Color.accentColor.opacity(0.18) }
        if isHovering { return Color.primary.opacity(0.08) }
        return .clear
    }

    // MARK: - 右クリックのメニュー

    @ViewBuilder
    private var menu: some View {
        if unit.contains(where: \.content.isPreviewable) {
            Button("Quick Look で見る") {
                model.selectForAction(first)
                model.onQuickLookRequest?()
            }
        }
        if !isStack, !isText(first) {
            Button("開く") { first.content.open() }
        }
        let files = unit.compactMap(fileURL)
        if !files.isEmpty {
            Button("Finder で表示") { NSWorkspace.shared.activateFileViewerSelecting(files) }
        }

        Divider()

        Button(isLocked ? "ロックを外す" : "ロック（取り出しても棚に残す）") {
            model.selectForAction(first)
            model.toggleLockOfSelection()
        }
        if isSelected, model.selectedUnitCount >= 2 {
            Button("選んだものをスタックにする") { model.stackSelected() }
        }
        if isStack {
            Button("スタックを分ける") { model.unstack(first) }
        }

        Divider()

        Button(isStack ? "スタックごと棚から外す" : "棚から外す") {
            if isSelected, model.selectedUnitCount > 1 {
                model.removeSelected()
            } else {
                model.removeItems(withIDs: Set(unit.map(\.id)))
            }
        }
    }

    private func openUnit() {
        model.click(first, modifier: .none)
        if isStack || isText(first) {
            model.onQuickLookRequest?()
        } else {
            first.content.open()
        }
    }

    private func isText(_ item: ShelfItem) -> Bool {
        if case .text = item.content { true } else { false }
    }

    private func fileURL(_ item: ShelfItem) -> URL? {
        if case .file(let url) = item.content { url } else { nil }
    }

    /// 今押している修飾キーから、選び方を決める
    private static func currentModifier() -> SelectionModifier {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) { return .toggle }
        if flags.contains(.shift) { return .range }
        return .none
    }
}

/// 中身の種類ごとのアイコン
struct ItemIcon: View {
    let content: ShelfItemContent

    var body: some View {
        switch content {
        case .file(let url):
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .scaledToFit()
        case .link:
            symbol("link")
        case .text:
            symbol("text.alignleft")
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(.tint)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary, in: .rect(cornerRadius: 10))
    }
}
