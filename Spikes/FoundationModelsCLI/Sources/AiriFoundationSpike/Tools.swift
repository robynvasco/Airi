import Foundation
import FoundationModels

@available(macOS 26.0, *)
struct ResolveRelativeDateTool: Tool {
    let name = "resolveRelativeDate"
    let description = "Resolve relative German or English date phrases to a local ISO date."

    let recorder: ToolCallRecorder
    let calendar: Calendar
    let referenceDate: Date

    typealias Arguments = GeneratedContent
    typealias Output = String

    var parameters: GenerationSchema {
        try! GenerationSchema(
            root: DynamicGenerationSchema(
                name: "ResolveRelativeDateArguments",
                properties: [
                    .init(
                        name: "phrase",
                        description: "Relative date phrase, such as next Monday, tomorrow, Freitag, or naechsten Montag.",
                        schema: .init(type: String.self)
                    )
                ]
            ),
            dependencies: []
        )
    }

    func call(arguments: Arguments) async throws -> String {
        let phrase = try arguments.value(String.self, forProperty: "phrase")
        await recorder.record("resolveRelativeDate(\"\(phrase)\")")

        let resolved = DateResolver(calendar: calendar, referenceDate: referenceDate)
            .resolve(phrase)

        if let resolved {
            return resolved
        }

        return "unresolved"
    }
}

@available(macOS 26.0, *)
struct FindContactCandidatesTool: Tool {
    let name = "findContactCandidates"
    let description = "Find local contact candidates for a mentioned first name or full name."

    let recorder: ToolCallRecorder

    typealias Arguments = GeneratedContent
    typealias Output = String

    var parameters: GenerationSchema {
        try! GenerationSchema(
            root: DynamicGenerationSchema(
                name: "FindContactCandidatesArguments",
                properties: [
                    .init(
                        name: "name",
                        description: "Name mentioned in the user's request.",
                        schema: .init(type: String.self)
                    )
                ]
            ),
            dependencies: []
        )
    }

    func call(arguments: Arguments) async throws -> String {
        let name = try arguments.value(String.self, forProperty: "name")
        await recorder.record("findContactCandidates(\"\(name)\")")

        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sampleContacts: [String: [String]] = [
            "anna": ["Anna Mueller <anna@example.local>", "Anna Schmidt <anna.schmidt@example.local>"],
            "robyn": ["Robyn Vasco <robyn@example.local>"]
        ]

        let matches = sampleContacts[normalized] ?? []
        if matches.isEmpty {
            return "no candidates found"
        }

        return matches.joined(separator: "\n")
    }
}

@available(macOS 26.0, *)
struct ListCalendarsTool: Tool {
    let name = "listCalendars"
    let description = "List calendars available for placing drafted events."

    let recorder: ToolCallRecorder

    typealias Arguments = GeneratedContent
    typealias Output = String

    var parameters: GenerationSchema {
        try! GenerationSchema(
            root: DynamicGenerationSchema(
                name: "ListCalendarsArguments",
                properties: [
                    .init(
                        name: "reason",
                        description: "Reason calendars are needed, such as default calendar or work event.",
                        schema: .init(type: String.self)
                    )
                ]
            ),
            dependencies: []
        )
    }

    func call(arguments: Arguments) async throws -> String {
        let reason = try arguments.value(String.self, forProperty: "reason")
        await recorder.record("listCalendars(\"\(reason)\")")

        return """
        Personal (default)
        Work
        Family
        """
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
        guard let date else { return nil }

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
