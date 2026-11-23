import Foundation

/// ドラッグ中に押すと棚が出るキー
public enum TriggerModifier: String, CaseIterable, Sendable {
    /// 使わない
    case none
    case shift
    case control
    /// ⌘（Finder では「移動」を選ぶキーでもある）
    case command

    /// そのキー（none なら空）
    public var keys: ModifierKeys {
        switch self {
        case .none: []
        case .shift: .shift
        case .control: .control
        case .command: .command
        }
    }
}

/// 押している修飾キー（AppKit に依存しない形）
public struct ModifierKeys: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let shift = ModifierKeys(rawValue: 1 << 0)
    public static let control = ModifierKeys(rawValue: 1 << 1)
    public static let option = ModifierKeys(rawValue: 1 << 2)
    public static let command = ModifierKeys(rawValue: 1 << 3)
}

/// ドラッグ中に修飾キーが押されたのを見つける（1 回のドラッグで 1 回だけ知らせる）
///
/// - 決めたキー「だけ」を押したときに知らせる（ほかの修飾キーと一緒に押していたら知らせない）
/// - ドラッグを始めたときにもう押していたら、一度離してから押し直したときに知らせる
///   （⇧ を押しながら選んで、そのままドラッグしたときに出ないように）
public struct ModifierTriggerDetector: Sendable {
    public let trigger: TriggerModifier
    /// 押していない状態を見たか（押したときに知らせてよいか）
    private var isArmed: Bool
    private var hasFired = false

    /// - Parameter initial: ドラッグを始めたときに押していた修飾キー
    public init(trigger: TriggerModifier, initial: ModifierKeys) {
        self.trigger = trigger
        isArmed = !Self.isPressed(trigger, in: initial)
    }

    /// 今押している修飾キーを伝える。棚を出すときに true を返す
    public mutating func update(_ keys: ModifierKeys) -> Bool {
        guard trigger != .none, !hasFired else { return false }
        if Self.isPressed(trigger, in: keys) {
            guard isArmed else { return false }
            hasFired = true
            return true
        }
        // 決めたキーを離した（または、ほかのキーと一緒に押している）: 次に押したら知らせる
        if keys.isDisjoint(with: trigger.keys) {
            isArmed = true
        }
        return false
    }

    /// 決めたキーだけを押しているか
    private static func isPressed(_ trigger: TriggerModifier, in keys: ModifierKeys) -> Bool {
        trigger != .none && keys == trigger.keys
    }
}
