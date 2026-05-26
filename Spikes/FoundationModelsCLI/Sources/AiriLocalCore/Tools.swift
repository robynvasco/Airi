import Foundation

public struct LocalToolResult {
    public var call: String
    public var output: String
}

public enum LocalToolRunner {
    public static func runTools(
        for extractions: [CalendarTaskExtraction],
        calendar: Calendar,
        availableCalendarNames: [String] = []
    ) -> [LocalToolResult] {
        var results: [LocalToolResult] = []
        var listedCalendars = false
        let resolver = DatePhraseResolver(calendar: calendar, referenceDate: Date())

        for item in extractions {
            let datePhrase = item.extraction.datePhrase
            if !datePhrase.isEmpty {
                results.append(
                    LocalToolResult(
                        call: "resolveDatePhrase(\"\(datePhrase)\")",
                        output: terminalDescription(for: resolver.resolve(datePhrase))
                    )
                )
            }

            for person in item.extraction.people {
                results.append(
                    LocalToolResult(
                        call: "findContactCandidates(\"\(person)\")",
                        output: contactCandidates(for: person)
                    )
                )
            }

            if !listedCalendars {
                results.append(
                    LocalToolResult(
                        call: "listCalendars(\"calendar event\")",
                        output: availableCalendarNames.isEmpty
                            ? "No calendars provided by the app layer."
                            : availableCalendarNames.joined(separator: "\n")
                    )
                )
                listedCalendars = true
            }
        }

        return results
    }

    private static func contactCandidates(for name: String) -> String {
        "Contact lookup is not connected yet for \(name)."
    }

    private static func terminalDescription(for resolution: DatePhraseResolution) -> String {
        switch resolution.status {
        case .resolved:
            return resolution.isoDate ?? "unresolved"
        case .ambiguous:
            return "ambiguous: \(resolution.message)"
        case .unresolved:
            return "unresolved: \(resolution.message)"
        }
    }
}
