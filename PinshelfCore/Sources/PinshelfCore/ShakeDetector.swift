import Foundation

/// シェイクと見なす条件
public struct ShakeConfiguration: Equatable, Sendable {
    /// 1 回の振りで動く最小の距離（pt）
    public var minimumStroke: Double
    /// シェイクと見なす折り返しの回数
    public var requiredReversals: Int
    /// 折り返しを数える時間の幅（秒）
    public var timeWindow: TimeInterval
    /// 1 回の振りにかけてよい最長の時間（秒）。これより遅い動きは振りと見なさない
    public var maximumStrokeDuration: TimeInterval

    public init(minimumStroke: Double, requiredReversals: Int, timeWindow: TimeInterval, maximumStrokeDuration: TimeInterval) {
        self.minimumStroke = minimumStroke
        self.requiredReversals = requiredReversals
        self.timeWindow = timeWindow
        self.maximumStrokeDuration = maximumStrokeDuration
    }

    /// 向きが変わったと見なすまでに戻る距離（手ぶれで折り返しを数えないため）
    var reversalHysteresis: Double { max(3, minimumStroke * 0.2) }

    /// 感度ごとの条件
    public static func preset(_ sensitivity: ShakeSensitivity) -> ShakeConfiguration {
        switch sensitivity {
        case .light:
            ShakeConfiguration(minimumStroke: 20, requiredReversals: 3, timeWindow: 0.8, maximumStrokeDuration: 0.3)
        case .normal:
            ShakeConfiguration(minimumStroke: 35, requiredReversals: 4, timeWindow: 0.9, maximumStrokeDuration: 0.3)
        case .firm:
            ShakeConfiguration(minimumStroke: 60, requiredReversals: 5, timeWindow: 1.0, maximumStrokeDuration: 0.35)
        }
    }
}

/// マウスの位置の並びからシェイク（素早い往復）を見つける
///
/// 横（x）と縦（y）をそれぞれ別に見て、どちらかで条件を満たしたらシェイクとする。
public struct ShakeDetector: Sendable {
    public var configuration: ShakeConfiguration

    private var xAxis = AxisTracker()
    private var yAxis = AxisTracker()
    private var xReversals: [TimeInterval] = []
    private var yReversals: [TimeInterval] = []

    public init(configuration: ShakeConfiguration) {
        self.configuration = configuration
    }

    /// 途中の状態を捨てる
    public mutating func reset() {
        xAxis = AxisTracker()
        yAxis = AxisTracker()
        xReversals.removeAll()
        yReversals.removeAll()
    }

    /// マウスの位置を 1 つ加える。シェイクを見つけたら true を返し、状態を捨てる
    public mutating func addSample(x: Double, y: Double, at time: TimeInterval) -> Bool {
        let xEvent = xAxis.feed(x, at: time, configuration: configuration)
        let yEvent = yAxis.feed(y, at: time, configuration: configuration)
        let hitX = Self.record(xEvent, at: time, into: &xReversals, configuration: configuration)
        let hitY = Self.record(yEvent, at: time, into: &yReversals, configuration: configuration)
        if hitX || hitY {
            reset()
            return true
        }
        return false
    }

    private static func record(
        _ event: AxisTracker.Event,
        at time: TimeInterval,
        into reversals: inout [TimeInterval],
        configuration: ShakeConfiguration
    ) -> Bool {
        switch event {
        case .validReversal:
            reversals.append(time)
        case .invalidStroke:
            // 遅い・短い振りが混じったら、そこまでの数え上げはやり直す
            reversals.removeAll()
        case .none:
            break
        }
        reversals.removeAll { time - $0 > configuration.timeWindow }
        return reversals.count >= configuration.requiredReversals
    }
}

/// 1 つの軸（x か y）の往復を追う
struct AxisTracker: Sendable {
    enum Event {
        case none
        /// 条件を満たす振りのあとで折り返した
        case validReversal
        /// 折り返したが、その振りは短すぎるか遅すぎた
        case invalidStroke
    }

    private var hasSample = false
    /// 今の振りの向き（-1・0・+1。0 はまだ動き出していない）
    private var direction = 0
    private var strokeStart = 0.0
    private var strokeStartTime: TimeInterval = 0
    /// 今の振りで最も遠くまで行った位置
    private var extreme = 0.0
    private var extremeTime: TimeInterval = 0

    mutating func feed(_ value: Double, at time: TimeInterval, configuration: ShakeConfiguration) -> Event {
        guard hasSample else {
            hasSample = true
            strokeStart = value
            strokeStartTime = time
            extreme = value
            extremeTime = time
            return .none
        }

        let hysteresis = configuration.reversalHysteresis

        if direction == 0 {
            let delta = value - strokeStart
            if abs(delta) >= hysteresis {
                direction = delta > 0 ? 1 : -1
                extreme = value
                extremeTime = time
            } else {
                // まだ止まっているので、振りの始まりの時刻を今にそろえる
                strokeStartTime = time
            }
            return .none
        }

        let progress = (value - extreme) * Double(direction)
        if progress > 0 {
            // 同じ向きにさらに進んだ
            extreme = value
            extremeTime = time
            return .none
        }

        guard -progress >= hysteresis else { return .none }

        // 折り返した
        let length = abs(extreme - strokeStart)
        let duration = extremeTime - strokeStartTime
        let isValid = length >= configuration.minimumStroke && duration <= configuration.maximumStrokeDuration

        // 折り返した点から新しい振りを始める
        strokeStart = extreme
        strokeStartTime = extremeTime
        direction = -direction
        extreme = value
        extremeTime = time

        return isValid ? .validReversal : .invalidStroke
    }
}
