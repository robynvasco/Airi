import Foundation

struct LocalToolResult {
    var call: String
    var output: String
}

enum LocalToolRunner {
    static func runTools(
        for tasks: [InputTask],
        dateHints: [(phrase: String, isoDate: String)]
    ) -> [LocalToolResult] {
        var results: [LocalToolResult] = []
        var listedCalendars = false

        for task in tasks {
            let taskHints = dateHintsForTask(task, dateHints: dateHints)
            for hint in taskHints {
                results.append(
                    LocalToolResult(
                        call: "resolveRelativeDate(\"\(hint.phrase)\")",
                        output: hint.isoDate
                    )
                )
            }

            let people = PeopleExtractor.explicitPeople(in: task)
            for person in people {
                results.append(
                    LocalToolResult(
                        call: "findContactCandidates(\"\(person)\")",
                        output: contactCandidates(for: person)
                    )
                )
            }

            if task.type == "calendarEvent" && !listedCalendars {
                results.append(
                    LocalToolResult(
                        call: "listCalendars(\"calendar event\")",
                        output: "Personal (default), Work, Family"
                    )
                )
                listedCalendars = true
            }
        }

        return results
    }

    private static func contactCandidates(for name: String) -> String {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sampleContacts: [String: [String]] = [
            "anna": ["Anna Mueller <anna@example.local>", "Anna Schmidt <anna.schmidt@example.local>"],
            "robyn": ["Robyn Vasco <robyn@example.local>"]
        ]

        return sampleContacts[normalized]?.joined(separator: "\n") ?? "no candidates found"
    }
}

struct DateResolver {
    var calendar: Calendar
    var referenceDate: Date

    func resolve(_ phrase: String) -> String? {
        let normalized = phrase
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        if normalized.contains("today") || normalized.contains("heute") {
            return iso(referenceDate)
        }

        if normalized.contains("tomorrow") || normalized.contains("morgen") {
            return iso(calendar.date(byAdding: .day, value: 1, to: referenceDate))
        }

        for (weekday, names) in weekdayNames {
            if names.contains(where: { normalized.contains($0) }) {
                return iso(nextDate(matchingWeekday: weekday))
            }
        }

        return nil
    }

    private func nextDate(matchingWeekday weekday: Int) -> Date? {
        var components = DateComponents()
        components.weekday = weekday

        return calendar.nextDate(
            after: referenceDate,
            matching: components,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }

    private func iso(_ date: Date?) -> String? {
        guard let date else {
            return nil
        }

        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day
        else {
            return nil
        }

        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private var weekdayNames: [(weekday: Int, names: [String])] {
        [
            (2, ["monday", "montag"]),
            (3, ["tuesday", "dienstag"]),
            (4, ["wednesday", "mittwoch"]),
            (5, ["thursday", "donnerstag"]),
            (6, ["friday", "freitag"]),
            (7, ["saturday", "samstag", "sonnabend"]),
            (1, ["sunday", "sonntag"])
        ]
    }
}
