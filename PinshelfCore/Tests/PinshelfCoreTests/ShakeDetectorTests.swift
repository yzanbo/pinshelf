import Foundation
import Testing
@testable import PinshelfCore

/// マウスの動きの標本（x, y, 時刻）
private typealias Sample = (x: Double, y: Double, t: Double)

/// 点から点へ一定の速さで動く 60Hz の標本を作る
private func path(from start: (Double, Double), through points: [(Double, Double)], segmentDuration: Double, startTime: Double = 0) -> [Sample] {
    var result: [Sample] = [(start.0, start.1, startTime)]
    var current = start
    var time = startTime
    for next in points {
        let steps = max(1, Int((segmentDuration * 60).rounded()))
        for step in 1...steps {
            let f = Double(step) / Double(steps)
            time += segmentDuration / Double(steps)
            result.append((current.0 + (next.0 - current.0) * f, current.1 + (next.1 - current.1) * f, time))
        }
        current = next
    }
    return result
}

/// 横に往復する点の並び
private func horizontalStrokes(count: Int, amplitude: Double, y: Double = 0) -> [(Double, Double)] {
    (1...count).map { ($0 % 2 == 1 ? amplitude : 0, y) }
}

/// 標本を順に与えて、シェイクを見つけた回数を返す
private func detections(_ samples: [Sample], _ sensitivity: ShakeSensitivity) -> Int {
    var detector = ShakeDetector(configuration: .preset(sensitivity))
    var count = 0
    for s in samples where detector.addSample(x: s.x, y: s.y, at: s.t) {
        count += 1
    }
    return count
}

@Suite("シェイクの判定")
struct ShakeDetectorTests {
    @Test("「軽く」なら 40pt の素早い往復で棚が出る")
    func lightShakeDetected() {
        let samples = path(from: (0, 0), through: horizontalStrokes(count: 5, amplitude: 40), segmentDuration: 0.1)
        #expect(detections(samples, .light) == 1)
    }

    @Test("「軽く」は 25pt ほどの小さな往復でも出る")
    func smallLightShakeDetected() {
        let samples = path(from: (0, 0), through: horizontalStrokes(count: 5, amplitude: 25), segmentDuration: 0.08)
        #expect(detections(samples, .light) == 1)
    }

    @Test("「しっかり」は 40pt の往復では出ず、80pt なら出る")
    func firmNeedsLargerStrokes() {
        let small = path(from: (0, 0), through: horizontalStrokes(count: 8, amplitude: 40), segmentDuration: 0.1)
        let large = path(from: (0, 0), through: horizontalStrokes(count: 8, amplitude: 80), segmentDuration: 0.12)
        #expect(detections(small, .firm) == 0)
        #expect(detections(large, .firm) == 1)
    }

    @Test("ゆっくりした往復はシェイクと見なさない")
    func slowMovementIgnored() {
        let samples = path(from: (0, 0), through: horizontalStrokes(count: 8, amplitude: 60), segmentDuration: 0.6)
        #expect(detections(samples, .light) == 0)
    }

    @Test("手ぶれ程度の小さな動きはシェイクと見なさない")
    func jitterIgnored() {
        let samples = path(from: (0, 0), through: horizontalStrokes(count: 12, amplitude: 8), segmentDuration: 0.05)
        #expect(detections(samples, .light) == 0)
    }

    @Test("まっすぐ動かすだけではシェイクと見なさない")
    func straightDragIgnored() {
        let samples = path(from: (0, 0), through: [(300, 100), (900, 200)], segmentDuration: 0.4)
        #expect(detections(samples, .light) == 0)
    }

    @Test("長く運んだあとに振っても見つける")
    func shakeAfterLongDrag() {
        let approach = path(from: (0, 0), through: [(600, 0)], segmentDuration: 1.0)
        let shake = path(from: (600, 0), through: [(640, 0), (600, 0), (640, 0), (600, 0), (640, 0)], segmentDuration: 0.1, startTime: 1.0)
        #expect(detections(approach + shake.dropFirst(), .light) == 1)
    }

    @Test("縦に振っても見つける")
    func verticalShakeDetected() {
        let points: [(Double, Double)] = (1...5).map { (0, $0 % 2 == 1 ? 40 : 0) }
        let samples = path(from: (0, 0), through: points, segmentDuration: 0.1)
        #expect(detections(samples, .light) == 1)
    }

    @Test("途中で間が空いたら数え直す")
    func pauseResetsCount() {
        let first = path(from: (0, 0), through: [(40, 0), (0, 0), (40, 0)], segmentDuration: 0.1)
        // 1 秒止まる
        let pause: [Sample] = (1...60).map { (40, 0, 0.3 + Double($0) / 60) }
        let second = path(from: (40, 0), through: [(0, 0), (40, 0)], segmentDuration: 0.1, startTime: 1.3)
        #expect(detections(first + pause + second.dropFirst(), .light) == 0)
    }

    @Test("一度見つけたら、続けて振っても次の条件がそろうまで出さない")
    func resetsAfterDetection() {
        let samples = path(from: (0, 0), through: horizontalStrokes(count: 6, amplitude: 40), segmentDuration: 0.1)
        #expect(detections(samples, .light) == 1)
    }
}
