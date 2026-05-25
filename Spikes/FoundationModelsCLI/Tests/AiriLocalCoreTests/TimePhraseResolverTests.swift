import XCTest
@testable import AiriLocalCore

final class TimePhraseResolverTests: XCTestCase {
    func testGermanTimePhrases() {
        XCTAssertEqual(TimePhraseResolver.resolve("um 9").time, "09:00")
        XCTAssertEqual(TimePhraseResolver.resolve("14 Uhr").time, "14:00")
        XCTAssertEqual(TimePhraseResolver.resolve("14:30").time, "14:30")
    }

    func testEnglishTimePhrases() {
        XCTAssertEqual(TimePhraseResolver.resolve("at 9").time, "09:00")
        XCTAssertEqual(TimePhraseResolver.resolve("2pm").time, "14:00")
    }
}
