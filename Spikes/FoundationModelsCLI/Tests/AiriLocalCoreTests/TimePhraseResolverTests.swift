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

    func testClockTimeValidation() {
        XCTAssertEqual(TimePhraseResolver.validateClockTime("10:00").time, "10:00")
        XCTAssertEqual(TimePhraseResolver.validateClockTime("24:00").status, .unresolved)
    }

    func testDurationBetweenClockTimes() {
        XCTAssertEqual(TimePhraseResolver.minutesBetween(startTime: "10:00", endTime: "11:00"), 60)
        XCTAssertEqual(TimePhraseResolver.minutesBetween(startTime: "12:00", endTime: "13:30"), 90)
        XCTAssertNil(TimePhraseResolver.minutesBetween(startTime: "12:00", endTime: "11:00"))
    }
}
