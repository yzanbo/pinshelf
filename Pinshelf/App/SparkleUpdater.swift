import AppKit
import os
import PinshelfCore
import Sparkle

/// Sparkle を使った更新（新しい版を確かめる・落とす・入れ替える）
///
/// 更新の画面（新しい版の知らせ・リリースノート・進み具合）は、Sparkle の標準のものを使う。
/// Pinshelf はメニューバーに常駐するアプリなので、自動で見つけた新しい版は画面に割り込ませず、
/// メニューバーのアイコンの印とメニューで知らせる（Sparkle の「控えめな知らせ」の作法）。
///
/// Sparkle を読み込むのはこのファイルだけ。画面の側（メニュー・設定）は `AppUpdates` を通して使う
/// （make readme-images は、Sparkle なしでアプリのコードをビルドするため、このファイルを除く）。
final class SparkleUpdater: NSObject, AppUpdateService, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    /// 更新の画面を出している間、Dock にアイコンを出しておく印
    private static let dockHold = "update"
    private static let logger = Logger(pinshelf: "update")

    private let updates: AppUpdates
    private var controller: SPUStandardUpdaterController?
    private var canCheckObservation: NSKeyValueObservation?

    /// 更新の仕組みを始める
    ///
    /// 更新ファイルの署名を確かめる公開鍵（Info.plist の SUPublicEDKey）が入っていないビルドでは始めず、nil を返す
    /// （鍵を作る前のビルド・自分でビルドしたもの。Sparkle に始めさせると、設定の不備の警告が出るため）。
    static func start(updates: AppUpdates) -> SparkleUpdater? {
        guard hasPublicKey else {
            logger.info("Updates are disabled: SUPublicEDKey is empty in this build")
            return nil
        }
        let updater = SparkleUpdater(updates: updates)
        guard updater.startUpdater() else { return nil }
        return updater
    }

    private static var hasPublicKey: Bool {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        return key?.isEmpty == false
    }

    private init(updates: AppUpdates) {
        self.updates = updates
        super.init()
    }

    private func startUpdater() -> Bool {
        // 始めるのは自分で行う（Sparkle の部品に任せると、失敗したときに英語の警告の画面が出る）
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: self)
        do {
            try controller.updater.start()
        } catch {
            Self.logger.error("Could not start the updater: \(error.localizedDescription, privacy: .public)")
            return false
        }
        self.controller = controller
        // 確かめられるかは、裏で確かめている間などに変わるので、変わるたびに画面の側へ伝える
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.updates.refresh() }
        }
        updates.attach(self)
        return true
    }

    // MARK: - AppUpdateService

    var checksAutomatically: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    var canCheck: Bool {
        controller?.updater.canCheckForUpdates ?? false
    }

    var lastCheckDate: Date? {
        controller?.updater.lastUpdateCheckDate
    }

    func checkForUpdates() {
        // 確かめられないとき（裏で確かめている途中など）は何もしない（Dock に出したままにならないように）
        guard let controller, controller.updater.canCheckForUpdates else { return }
        // Pinshelf はふだん前面のアプリにならないので、Dock に出して前面にしてから確かめる（更新の画面が後ろに隠れないように）。
        // Dock からは、確かめ終えたとき（didFinishUpdateCycleFor）に消す
        DockIcon.hold(Self.dockHold)
        NSApp.activate()
        controller.checkForUpdates(nil)
    }

    // MARK: - SPUUpdaterDelegate

    /// 確かめ終えた（新しい版がなかった・あとにした・失敗したときも）。Dock から消して、最後に確かめた日時を画面に反映する
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        DockIcon.release(Self.dockHold)
        updates.refresh()
    }

    // MARK: - SPUStandardUserDriverDelegate（控えめな知らせ）

    var supportsGentleScheduledUpdateReminders: Bool { true }

    /// 自動で見つけた新しい版は、Sparkle に画面を出させず、メニューバーで知らせる（起動してすぐのときも割り込まない）
    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        false
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        // どう知らせたかを記録に残す（自動で見つけたときに、画面を割り込ませていないことを、あとから確かめられるように）
        let notice = handleShowingUpdate ? "showing the update window" : "showing the menu bar badge"
        Self.logger.notice("Found version \(update.displayVersionString, privacy: .public): \(notice, privacy: .public)")
        if handleShowingUpdate {
            // Sparkle が更新の画面を出す（メニューから確かめたとき）。出している間は Dock に出す
            DockIcon.hold(Self.dockHold)
        } else {
            updates.noteUpdateFound(version: update.displayVersionString)
        }
    }

    /// 更新の画面を見てもらった（入れる・あとにする・この版を飛ばすを選んだときも）
    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        updates.clearPendingUpdate()
    }

    func standardUserDriverWillFinishUpdateSession() {
        updates.clearPendingUpdate()
        DockIcon.release(Self.dockHold)
    }
}
