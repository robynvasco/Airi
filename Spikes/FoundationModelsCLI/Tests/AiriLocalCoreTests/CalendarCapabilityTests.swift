import XCTest
@testable import AiriLocalCore

final class CalendarCapabilityTests: XCTestCase {
    func testReadyCalendarProposal() {
        let proposals = CalendarCapability.propose(
            from: [
                extraction(
                    title: "Call mit Anna",
                    datePhrase: "Mittwoch",
                    timePhrase: "14 Uhr",
                    people: ["Anna"]
                )
            ],
            calendar: calendar,
            referenceDate: referenceDate
        )

        XCTAssertEqual(proposals.count, 1)
        XCTAssertEqual(proposals[0].status, .ready)
        XCTAssertEqual(proposals[0].draft.title, "Call mit Anna")
        XCTAssertEqual(proposals[0].draft.startDate, "2026-05-27")
        XCTAssertEqual(proposals[0].draft.startTime, "14:00")
        XCTAssertEqual(proposals[0].draft.participants, ["Anna"])
        XCTAssertTrue(proposals[0].clarificationQuestions.isEmpty)
    }

    func testAmbiguousDateNeedsClarification() {
        let proposals = CalendarCapability.propose(
            from: [
                extraction(
                    title: "Steuertermin",
                    datePhrase: "01. Mai",
                    timePhrase: "um 10",
                    people: []
                )
            ],
            calendar: calendar,
            referenceDate: referenceDate
        )

        XCTAssertEqual(proposals.count, 1)
        XCTAssertEqual(proposals[0].status, .needsClarification)
        XCTAssertEqual(proposals[0].draft.title, "Steuertermin")
        XCTAssertEqual(proposals[0].draft.startDate, "")
        XCTAssertEqual(proposals[0].draft.startTime, "10:00")
        XCTAssertEqual(proposals[0].clarificationQuestions.map(\.field), ["date"])
    }

    private func extraction(
        title: String,
        datePhrase: String,
        timePhrase: String,
        people: [String]
    ) -> CalendarTaskExtraction {
        CalendarTaskExtraction(
            task: InputTask(index: 1, text: title, source: .model, type: "calendarEvent"),
            extraction: CalendarExtraction(
                type: "calendarEvent",
                title: title,
                datePhrase: datePhrase,
                timePhrase: timePhrase,
                people: people
            ),
            rawJSON: "{}"
        )
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "de_DE")
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private var referenceDate: Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2026
        components.month = 5
        components.day = 25
        components.hour = 12
        return calendar.date(from: components)!
    }
}
