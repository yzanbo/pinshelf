import PinshelfCore
import SwiftUI
import UniformTypeIdentifiers

/// 「除外するアプリ」のタブ: ドラッグを始めても、棚を自動では出さないアプリ
struct IgnoredAppsSettingsView: View {
    @State private var bundleIDs = ShelfBehaviorSettings(defaults: .standard).ignoredBundleIDs

    var body: some View {
        SettingsPane {
            Section {
                if bundleIDs.isEmpty {
                    Text("まだありません")
                        .foregroundStyle(.secondary)
                }
                ForEach(bundleIDs, id: \.self) { bundleID in
                    HStack(spacing: 8) {
                        Image(nsImage: AppInfo.icon(for: bundleID, size: 20))
                        Text(AppInfo.name(for: bundleID))
                        Spacer()
                        Button {
                            remove(bundleID)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.borderless)
                        .help("一覧から外す")
                    }
                }
                HStack {
                    Spacer()
                    addMenu
                }
            } header: {
                SettingTitle(
                    "自動では出さないアプリ",
                    info: "デザインツールなど、ドラッグをよく使うアプリに向いています。判断に使うのは、ドラッグを始めたときに前面にあるアプリです。"
                )
            } footer: {
                SettingsNote("これらのアプリでドラッグを始めたときは、画面の端の棚も、振って出す棚も、自動では出しません。キーで出す・メニューバーから開くのは、いつでも使えます。")
            }
        }
    }

    private var addMenu: some View {
        Menu("アプリを追加") {
            let running = runningApps
            if running.isEmpty {
                Text("追加できる起動中のアプリはありません")
            }
            ForEach(running, id: \.self) { bundleID in
                Button {
                    add([bundleID])
                } label: {
                    Label {
                        Text(AppInfo.name(for: bundleID))
                    } icon: {
                        Image(nsImage: AppInfo.icon(for: bundleID, size: 16))
                    }
                }
            }
            Divider()
            Button("その他のアプリを選ぶ…") { chooseApps() }
        }
        .fixedSize()
    }

    /// 起動中のアプリのうち、まだ一覧にないもの
    private var runningApps: [String] {
        let own = Bundle.main.bundleIdentifier
        let ids = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.bundleIdentifier)
            .filter { $0 != own && !bundleIDs.contains($0) }
        return Array(Set(ids)).sorted { AppInfo.name(for: $0).localizedStandardCompare(AppInfo.name(for: $1)) == .orderedAscending }
    }

    private func add(_ ids: [String]) {
        for id in ids where !bundleIDs.contains(id) {
            bundleIDs.append(id)
        }
        save()
    }

    private func remove(_ id: String) {
        bundleIDs.removeAll { $0 == id }
        save()
    }

    private func save() {
        UserDefaults.standard.set(bundleIDs, forKey: ShelfBehaviorSettings.Key.ignoredApplications)
    }

    /// アプリケーションフォルダからアプリを選ぶ
    private func chooseApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "追加"
        panel.message = "棚を自動では出さないアプリを選んでください"
        guard panel.runModal() == .OK else { return }
        add(panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier })
    }
}

/// バンドル ID からアプリの名前とアイコンを引く
enum AppInfo {
    static func name(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    static func icon(for bundleID: String, size: CGFloat) -> NSImage {
        let image: NSImage
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            image = (NSWorkspace.shared.icon(forFile: url.path).copy() as? NSImage) ?? NSImage()
        } else {
            image = (NSWorkspace.shared.icon(for: .application).copy() as? NSImage) ?? NSImage()
        }
        image.size = NSSize(width: size, height: size)
        return image
    }
}
