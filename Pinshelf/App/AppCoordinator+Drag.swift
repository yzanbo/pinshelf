import AppKit
import PinshelfCore

/// ドラッグに合わせて棚を出す（画面端の棚・振る・修飾キー・しまった棚）
extension AppCoordinator {
    // MARK: - ドラッグ

    func dragBegan(at location: CGPoint, startedIn window: NSWindow?) {
        settings = TriggerSettings(defaults: .standard)
        hasOpenedShelfInThisDrag = false

        // 修飾キーで出すのは利用者がはっきり選んだ操作なので、自動では出さないアプリの中でも使える
        modifierDetector = ModifierTriggerDetector(
            trigger: settings.triggerModifier,
            initial: ModifierKeys(NSEvent.modifierFlags)
        )

        // 自動では出さないアプリでドラッグを始めたときは、画面端の棚もシェイクも使わない
        let behavior = ShelfBehaviorSettings(defaults: .standard)
        guard TriggerPolicy.allowsAutomaticShelf(
            frontmostBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            startedInPinshelf: window != nil,
            ignored: behavior.ignoredBundleIDs
        ) else {
            isShakeArmed = false
            isEdgeShelfArmed = false
            return
        }

        isShakeArmed = settings.triggerMode.usesShake
        if isShakeArmed {
            shakeDetector = ShakeDetector(configuration: .preset(settings.shakeSensitivity))
        }

        // 画面端の棚から取り出すドラッグでは、画面端の棚そのものは出し入れしない。
        // 浮いた棚から始まったドラッグでは出す（画面端の棚へ移せるように）
        let startedInEdgeShelf = window != nil && window === edgeDriver.shelf?.panel
        isEdgeShelfArmed = settings.triggerMode.usesEdge && !startedInEdgeShelf
        if isEdgeShelfArmed {
            edgeDriver.dragBegan(at: location, settings: settings)
        }
    }

    func dragMoved(to location: CGPoint, at time: TimeInterval) {
        if isEdgeShelfArmed {
            edgeDriver.dragMoved(to: location)
        }
        // 画面の端の棚は、帯に近づけたら開く（ドラッグで出た棚も同じ。隠している棚は除く）
        for shelf in shelvesFollowingDrag {
            shelf.dragMoved(to: location)
        }

        // 振る・修飾キーを押すと、カーソルの位置に棚を出す（1 回のドラッグで 1 つまで）
        guard !hasOpenedShelfInThisDrag else { return }
        let shaken = isShakeArmed && shakeDetector.addSample(x: location.x, y: location.y, at: time)
        let keyPressed = modifierDetector.update(ModifierKeys(NSEvent.modifierFlags))
        if shaken || keyPressed {
            hasOpenedShelfInThisDrag = true
            isShakeArmed = false
            let shelf = openShelf(centeredAt: location)
            shelvesOpenedInThisDrag.append(shelf)
        }
    }

    func dragEnded() {
        for shelf in shelvesFollowingDrag {
            shelf.dragEnded()
        }
        if isEdgeShelfArmed {
            edgeDriver.dragEnded()
            isEdgeShelfArmed = false
        }
        isShakeArmed = false

        // ドロップの読み込みが終わるのを待ってから、空のままの棚を閉じる
        let openedShelves = shelvesOpenedInThisDrag
        shelvesOpenedInThisDrag.removeAll()
        guard !openedShelves.isEmpty else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            for shelf in openedShelves where shelf.model.isEmpty && shelf.model.isSettled {
                shelf.close()
            }
        }
    }
}

extension AppCoordinator {
    /// ドラッグに合わせて自分で出し入れする、しまった棚（隠している棚は除く。画面端の棚も、ほかの棚と同じく自分でする）
    fileprivate var shelvesFollowingDrag: [ShelfController] {
        shelves.filter { !$0.isHidden }
    }
}

extension ModifierKeys {
    /// AppKit の修飾キーから作る
    init(_ flags: NSEvent.ModifierFlags) {
        var keys: ModifierKeys = []
        if flags.contains(.shift) { keys.insert(.shift) }
        if flags.contains(.control) { keys.insert(.control) }
        if flags.contains(.option) { keys.insert(.option) }
        if flags.contains(.command) { keys.insert(.command) }
        self = keys
    }
}
