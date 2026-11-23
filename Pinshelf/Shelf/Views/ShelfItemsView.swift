import PinshelfCore
import SwiftUI

// MARK: - 棚の中身

/// 棚に置いたものの一覧（空なら案内を出す）
struct ShelfItemsView: View {
    let model: ShelfModel
    /// 棚の横幅（列の数を決める。スクロールバーが出ても列が減らないよう、一覧の横幅ではなく棚の横幅で決める）
    let shelfWidth: CGFloat

    /// 並べる列（列の数は棚の横幅で決め、スクロールバーが出たときは 1 つ分を少し狭くする）
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(maximum: ShelfGridLayout.maximumTileWidth), spacing: ShelfGridLayout.spacing),
            count: ShelfGridLayout.columnCount(forShelfWidth: shelfWidth)
        )
    }

    /// 何もないところの右クリック
    @ViewBuilder
    private var pasteMenu: some View {
        Button("貼り付ける（⌘V）") { model.pasteFromClipboard() }
            .disabled(!ClipboardImporter.hasContents())
    }

    var body: some View {
        if model.items.isEmpty {
            VStack(spacing: 8) {
                // アプリの印
                AppSymbolImage(size: 30)
                Text("ここにドロップ")
                    .font(.callout)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(.tertiary)
                    .padding(10)
            )
            .contentShape(Rectangle())
            .contextMenu { pasteMenu }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(model.units, id: \.first?.id) { unit in
                        ShelfUnitTile(unit: unit, model: model)
                    }
                }
                .padding(ShelfGridLayout.padding)
            }
            // 何もないところを押したら、選ぶのをやめる
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { model.clearSelection() }
                    .contextMenu { pasteMenu }
            }
            // ドラッグでつかんだものを調べるため、一覧の範囲とそれぞれの枠を棚に知らせる
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ShelfItemsAreaKey.self,
                        value: proxy.frame(in: .named(ShelfDragSource.coordinateSpace))
                    )
                }
            }
            .onPreferenceChange(ShelfItemsAreaKey.self) { area in
                MainActor.assumeIsolated { model.itemsArea = area }
            }
            .onPreferenceChange(ShelfTileFramesKey.self) { frames in
                MainActor.assumeIsolated { model.tileFrames = frames }
            }
            // 帯に畳んだときなどは一覧が見えないので、隠れたものをつかまないよう範囲を消す
            .onDisappear {
                model.itemsArea = .zero
            }
        }
    }
}
