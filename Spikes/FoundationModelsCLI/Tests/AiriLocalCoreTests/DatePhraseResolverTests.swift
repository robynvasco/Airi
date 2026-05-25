import XCTest
@testable import AiriLocalCore

final class DatePhraseResolverTests: XCTestCase {
    func testRelativeDayPhrases() {
        let resolver = makeResolver()

        XCTAssertEqual(resolver.resolve("heute").isoDate, "2026-05-25")
        XCTAssertEqual(resolver.resolve("morgen").isoDate, "2026-05-26")
        XCTAssertEqual(resolver.resolve("uebermorgen").isoDate, "2026-05-27")
        XCTAssertEqual(resolver.resolve("übermorgen").isoDate, "2026-05-27")
    }

    func testWeekdays() {
        let resolver = makeResolver()

        XCTAssertEqual(resolver.resolve("Mittwoch").isoDate, "2026-05-27")
        XCTAssertEqual(resolver.resolve("naechsten Montag").isoDate, "2026-06-01")
        XCTAssertEqual(resolver.resolve("nächste Woche Mittwoch").isoDate, "2026-06-03")
        XCTAssertEqual(resolver.resolve("übernächste Woche Mittwoch").isoDate, "2026-06-10")
    }

    func testExplicitFutureDatesWithoutYear() {
        let resolver = makeResolver()

        XCTAssertEqual(resolver.resolve("01. Juni").isoDate, "2026-06-01")
        XCTAssertEqual(resolver.resolve("1.6.").isoDate, "2026-06-01")
    }

    func testExplicitPastDatesWithoutYearAreAmbiguous() {
        let resolver = makeResolver()
        let resolution = resolver.resolve("01. Mai")

        XCTAssertEqual(resolution.status, .ambiguous)
        XCTAssertNil(resolution.isoDate)
    }

    func testExplicitDatesWithYear() {
        let resolver = makeResolver()

        XCTAssertEqual(resolver.resolve("01. Mai 2027").isoDate, "2027-05-01")
        XCTAssertEqual(resolver.resolve("1.5.2027").isoDate, "2027-05-01")
    }

    private func makeResolver() -> DatePhraseResolver {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "de_DE")
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2026
        components.month = 5
        components.day = 25
        components.hour = 12

        return DatePhraseResolver(
            calendar: calendar,
            referenceDate: calendar.date(from: components)!
        )
    }
}
