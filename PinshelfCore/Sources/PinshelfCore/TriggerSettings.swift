import Foundation

/// ドラッグ中に棚を出す方法
public enum TriggerMode: String, CaseIterable, Sendable {
    /// 画面端に棚を出す
    case edge
    /// マウスを振るとカーソルの位置に棚を出す
    case shake
    /// 両方
    case both
    /// どちらも使わない（キー・メニューバーからだけ出す）
    case off

    public var usesEdge: Bool { self == .edge || self == .both }
    public var usesShake: Bool { self == .shake || self == .both }

    /// 「画面端の棚を使う」「振ったら出す」の 2 つのスイッチから組み立てる
    public init(usesEdge: Bool, usesShake: Bool) {
        switch (usesEdge, usesShake) {
        case (true, true): self = .both
        case (true, false): self = .edge
        case (false, true): self = .shake
        case (false, false): self = .off
        }
    }
}

/// 画面端の棚をどちらの端に出すか
public enum EdgePreference: String, CaseIterable, Sendable {
    /// カーソルに近いほうの端
    case nearest
    case left
    case right
}

/// 画面端の棚が出るタイミング
public enum EdgeRevealTiming: String, CaseIterable, Sendable {
    /// ドラッグを始めたらすぐ細い帯を出し、端に近づくと広げる
    case onDragStart
    /// 端に近づいたときだけ出す
    case onApproach
}

/// 画面端の棚を出す高さ
public enum EdgeVerticalPosition: String, CaseIterable, Sendable {
    /// 端の上のほう
    case top
    /// 端の真ん中
    case middle
    /// 端の下のほう
    case bottom
    /// カーソルの高さ（ドラッグ中は帯がカーソルについてくる）
    case cursor
}

/// シェイクの感度
public enum ShakeSensitivity: String, CaseIterable, Sendable {
    /// 小さく軽く振るだけで出る
    case light
    case normal
    /// 大きくしっかり振ったときだけ出る
    case firm
}

/// 棚の出し方に関する設定
public struct TriggerSettings: Equatable, Sendable {
    /// UserDefaults に保存するときのキー
    public enum Key {
        public static let triggerMode = "triggerMode"
        public static let edgePreference = "edgePreference"
        public static let edgeRevealTiming = "edgeRevealTiming"
        public static let shakeSensitivity = "shakeSensitivity"
        public static let triggerModifier = "triggerModifier"
        public static let edgeVerticalPosition = "edgeVerticalPosition"
    }

    public var triggerMode: TriggerMode
    public var edgePreference: EdgePreference
    public var edgeRevealTiming: EdgeRevealTiming
    public var shakeSensitivity: ShakeSensitivity
    /// ドラッグ中に押すと、カーソルの位置に棚が出るキー（出し方の設定とは別に使える）
    public var triggerModifier: TriggerModifier
    /// 画面端の棚を出す高さ
    public var edgeVerticalPosition: EdgeVerticalPosition

    public init(
        triggerMode: TriggerMode = .both,
        edgePreference: EdgePreference = .nearest,
        edgeRevealTiming: EdgeRevealTiming = .onDragStart,
        shakeSensitivity: ShakeSensitivity = .light,
        triggerModifier: TriggerModifier = .shift,
        edgeVerticalPosition: EdgeVerticalPosition = .cursor
    ) {
        self.triggerMode = triggerMode
        self.edgePreference = edgePreference
        self.edgeRevealTiming = edgeRevealTiming
        self.shakeSensitivity = shakeSensitivity
        self.triggerModifier = triggerModifier
        self.edgeVerticalPosition = edgeVerticalPosition
    }

    /// 初期値
    public static let defaults = TriggerSettings()

    /// キーから文字列を読む関数を使って設定を組み立てる（読めない値は初期値にする）
    public init(reading value: (String) -> String?) {
        let base = TriggerSettings.defaults
        self.init(
            triggerMode: value(Key.triggerMode).flatMap(TriggerMode.init(rawValue:)) ?? base.triggerMode,
            edgePreference: value(Key.edgePreference).flatMap(EdgePreference.init(rawValue:)) ?? base.edgePreference,
            edgeRevealTiming: value(Key.edgeRevealTiming).flatMap(EdgeRevealTiming.init(rawValue:)) ?? base.edgeRevealTiming,
            shakeSensitivity: value(Key.shakeSensitivity).flatMap(ShakeSensitivity.init(rawValue:)) ?? base.shakeSensitivity,
            triggerModifier: value(Key.triggerModifier).flatMap(TriggerModifier.init(rawValue:)) ?? base.triggerModifier,
            edgeVerticalPosition: value(Key.edgeVerticalPosition).flatMap(EdgeVerticalPosition.init(rawValue:)) ?? base.edgeVerticalPosition
        )
    }

    /// UserDefaults から設定を読む
    public init(defaults store: UserDefaults) {
        self.init(reading: { store.string(forKey: $0) })
    }
}
