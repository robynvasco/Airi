import XCTest
@testable import AiriLocalCore

final class CalendarCapabilityTests: XCTestCase {
    func testReadyCalendarProposal() {
        let proposals = CalendarCapability.propose(
            from: [
                extraction(
                    title: "Call mit Anna",
                    datePhrase: "Mittwoch",
                    startTime: "14:00",
                    endTime: "15:00",
                    durationMinutes: 60,
                    location: "online",
                    people: ["Anna"],
                    notes: ""
                )
            ],
            calendar: calendar,
            referenceDate: referenceDate
        )

        XCTAssertEqual(proposals.count, 1)
        XCTAssertEqual(proposals[0].id, "calendar-1")
        XCTAssertTrue(proposals[0].isSelected)
        XCTAssertEqual(proposals[0].sourceInstruction, "Call mit Anna")
        XCTAssertEqual(proposals[0].reviewStatus, .ready)
        XCTAssertEqual(proposals[0].draft.title, "Call mit Anna")
        XCTAssertEqual(proposals[0].draft.startDate, "2026-05-27")
        XCTAssertEqual(proposals[0].draft.startTime, "14:00")
        XCTAssertEqual(proposals[0].draft.endTime, "15:00")
        XCTAssertEqual(proposals[0].draft.durationMinutes, 60)
        XCTAssertEqual(proposals[0].draft.location, "online")
        XCTAssertEqual(proposals[0].draft.participants, ["Anna"])
        XCTAssertTrue(proposals[0].warnings.isEmpty)
    }

    func testAmbiguousDateNeedsReviewWarning() {
        let proposals = CalendarCapability.propose(
            from: [
                extraction(
                    title: "Steuertermin",
                    datePhrase: "01. Mai",
                    startTime: "10:00",
                    endTime: "11:00",
                    durationMinutes: 60,
                    location: "",
                    people: [],
                    notes: ""
                )
            ],
            calendar: calendar,
            referenceDate: referenceDate
        )

        XCTAssertEqual(proposals.count, 1)
        XCTAssertEqual(proposals[0].reviewStatus, .needsReview)
        XCTAssertEqual(proposals[0].draft.title, "Steuertermin")
        XCTAssertEqual(proposals[0].draft.startDate, "")
        XCTAssertEqual(proposals[0].draft.startTime, "10:00")
        XCTAssertEqual(proposals[0].draft.endTime, "11:00")
        XCTAssertEqual(proposals[0].warnings.map(\.field), ["date"])
    }

    func testInvalidEndTimeNeedsReviewWarning() {
        let proposals = CalendarCapability.propose(
            from: [
                extraction(
                    title: "Termin",
                    datePhrase: "Mittwoch",
                    startTime: "12:00",
                    endTime: "11:00",
                    durationMinutes: 60,
                    location: "",
                    people: [],
                    notes: ""
                )
            ],
            calendar: calendar,
            referenceDate: referenceDate
        )

        XCTAssertEqual(proposals[0].reviewStatus, .needsReview)
        XCTAssertEqual(proposals[0].warnings.map(\.field), ["duration"])
    }

    func testUsesExtractedCalendarWhenAvailable() {
        let proposals = CalendarCapability.propose(
            from: [
                extraction(
                    title: "Team Call",
                    datePhrase: "Mittwoch",
                    startTime: "12:00",
                    endTime: "13:00",
                    durationMinutes: 60,
                    location: "",
                    people: [],
                    calendarName: "Arbeit",
                    notes: ""
                )
            ],
            calendar: calendar,
            referenceDate: referenceDate,
            availableCalendarNames: ["Privat", "Arbeit"]
        )

        XCTAssertEqual(proposals[0].draft.calendarName, "Arbeit")
        XCTAssertEqual(proposals[0].reviewStatus, .ready)
    }

    func testMissingCalendarUsesFirstAvailableCalendarAndWarns() {
        let proposals = CalendarCapability.propose(
            from: [
                extraction(
                    title: "Team Call",
                    datePhrase: "Mittwoch",
                    startTime: "12:00",
                    endTime: "13:00",
                    durationMinutes: 60,
                    location: "",
                    people: [],
                    calendarName: "",
                    notes: ""
                )
            ],
            calendar: calendar,
            referenceDate: referenceDate,
            availableCalendarNames: ["Privat", "Arbeit"]
        )

        XCTAssertEqual(proposals[0].draft.calendarName, "Privat")
        XCTAssertEqual(proposals[0].reviewStatus, .needsReview)
        XCTAssertEqual(proposals[0].warnings.map(\.field), ["calendar"])
    }

    private func extraction(
        title: String,
        datePhrase: String,
        startTime: String,
        endTime: String,
        durationMinutes: Int,
        location: String,
        people: [String],
        calendarName: String = "",
        notes: String
    ) -> CalendarTaskExtraction {
        CalendarTaskExtraction(
            task: InputTask(index: 1, instruction: title, source: .model, type: "calendarEvent"),
            extraction: CalendarExtraction(
                type: "calendarEvent",
                title: title,
                datePhrase: datePhrase,
                startTime: startTime,
                endTime: endTime,
                durationMinutes: durationMinutes,
                location: location,
                people: people,
                calendarName: calendarName,
                notes: notes
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
