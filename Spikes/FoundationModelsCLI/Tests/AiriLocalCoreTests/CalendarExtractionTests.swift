import XCTest
@testable import AiriLocalCore

final class CalendarExtractionTests: XCTestCase {
    func testMissingCalendarNameDefaultsToEmptyString() throws {
        let json = """
        {
          "type": "calendarEvent",
          "title": "Call mit Anna",
          "datePhrase": "Mittwoch",
          "startTime": "14:00",
          "endTime": "15:00",
          "durationMinutes": 60,
          "location": "",
          "people": ["Anna"],
          "notes": ""
        }
        """

        let extraction = try JSONDecoder().decode(CalendarExtraction.self, from: Data(json.utf8))

        XCTAssertEqual(extraction.calendarName, "")
    }
}
