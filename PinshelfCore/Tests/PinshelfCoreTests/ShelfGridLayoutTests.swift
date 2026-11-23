import CoreGraphics
import Testing
@testable import PinshelfCore

@Suite("棚の中身の並べ方")
struct ShelfGridLayoutTests {
    @Test("列の数は棚の横幅で決まる")
    func columnsByWidth() {
        #expect(ShelfGridLayout.columnCount(forShelfWidth: 150) == 1)
        #expect(ShelfGridLayout.columnCount(forShelfWidth: 180) == 2)
        #expect(ShelfGridLayout.columnCount(forShelfWidth: 240) == 3)
        #expect(ShelfGridLayout.columnCount(forShelfWidth: 1000) == 13)
    }

    @Test("とても狭くても 1 列は並べる")
    func atLeastOneColumn() {
        #expect(ShelfGridLayout.columnCount(forShelfWidth: 0) == 1)
        #expect(ShelfGridLayout.columnCount(forShelfWidth: 50) == 1)
    }
}
