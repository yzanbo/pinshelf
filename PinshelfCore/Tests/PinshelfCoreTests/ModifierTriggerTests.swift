import Testing
@testable import PinshelfCore

/// 押している修飾キーを順に伝えて、それぞれで知らせたか（棚を出すか）を返す
private func feed(_ trigger: TriggerModifier, initial: ModifierKeys = [], _ sequence: [ModifierKeys]) -> [Bool] {
    var detector = ModifierTriggerDetector(trigger: trigger, initial: initial)
    return sequence.map { detector.update($0) }
}

@Suite("修飾キーで出す")
struct ModifierTriggerTests {
    @Test("ドラッグ中に決めたキーを押すと、1 回だけ知らせる")
    func firesOnce() {
        // 押したまま・押し直しても、もう知らせない（1 回のドラッグで棚は 1 つ）
        let results = feed(.shift, [[], .shift, .shift, [], .shift])
        #expect(results == [false, true, false, false, false])
    }

    @Test("ドラッグを始めたときにもう押していたら、離して押し直したときに知らせる")
    func heldAtStart() {
        let results = feed(.shift, initial: .shift, [.shift, [], .shift])
        #expect(results == [false, false, true])
    }

    @Test("ほかの修飾キーと一緒に押したときは知らせない")
    func ignoresCombinations() {
        // ほかのキーを離して、決めたキーだけになったら知らせる
        let results = feed(.shift, [[.shift, .option], [.shift, .command], [], .shift])
        #expect(results == [false, false, false, true])
    }

    @Test("ほかのキーを押したまま決めたキーを足しても、決めたキーだけになるまで知らせない")
    func otherKeyHeld() {
        let results = feed(.control, initial: .option, [[.option, .control], .option, .control])
        #expect(results == [false, false, true])
    }

    @Test("決めたキー以外を押しても知らせない")
    func otherKeys() {
        let results = feed(.control, [.shift, .option, .command, .control])
        #expect(results == [false, false, false, true])
    }

    @Test("「なし」なら何を押しても知らせない")
    func disabled() {
        let results = feed(.none, [[], .shift, .control, .command])
        #expect(results == [false, false, false, false])
    }
}
