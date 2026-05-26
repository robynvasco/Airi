import Foundation

public struct CalendarExtraction: Decodable, Sendable {
    public var type: String
    public var title: String
    public var datePhrase: String
    public var startTime: String
    public var endTime: String
    public var durationMinutes: Int
    public var location: String
    public var people: [String]
    public var calendarName: String
    public var notes: String

    private enum CodingKeys: String, CodingKey {
        case type
        case title
        case datePhrase
        case startTime
        case endTime
        case durationMinutes
        case location
        case people
        case calendarName
        case notes
    }

    public init(
        type: String,
        title: String,
        datePhrase: String,
        startTime: String,
        endTime: String,
        durationMinutes: Int,
        location: String,
        people: [String],
        calendarName: String,
        notes: String
    ) {
        self.type = type
        self.title = title
        self.datePhrase = datePhrase
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.location = location
        self.people = people
        self.calendarName = calendarName
        self.notes = notes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        datePhrase = try container.decode(String.self, forKey: .datePhrase)
        startTime = try container.decode(String.self, forKey: .startTime)
        endTime = try container.decode(String.self, forKey: .endTime)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        location = try container.decode(String.self, forKey: .location)
        people = try container.decode([String].self, forKey: .people)
        calendarName = try container.decodeIfPresent(String.self, forKey: .calendarName) ?? ""
        notes = try container.decode(String.self, forKey: .notes)
    }
}

public struct CalendarTaskExtraction: Sendable {
    public var task: InputTask
    public var extraction: CalendarExtraction
    public var rawJSON: String

    public init(task: InputTask, extraction: CalendarExtraction, rawJSON: String) {
        self.task = task
        self.extraction = extraction
        self.rawJSON = rawJSON
    }
}

public enum CalendarExtractionFormatter {
    public static func terminalDescription(for extractions: [CalendarTaskExtraction]) -> String {
        guard !extractions.isEmpty else {
            return "- none"
        }

        return extractions.map { item in
            let people = item.extraction.people.isEmpty
                ? "none"
                : item.extraction.people.joined(separator: ", ")

            return """
            - Task \(item.task.index): \(item.task.text)
              Title: \(item.extraction.title)
              Date phrase: \(emptyFallback(item.extraction.datePhrase))
              Start time: \(emptyFallback(item.extraction.startTime))
              End time: \(emptyFallback(item.extraction.endTime))
              Duration: \(item.extraction.durationMinutes)m
              Location: \(emptyFallback(item.extraction.location))
              People: \(people)
              Calendar: \(emptyFallback(item.extraction.calendarName))
              Notes: \(emptyFallback(item.extraction.notes))
            """
        }
        .joined(separator: "\n")
    }

    private static func emptyFallback(_ value: String) -> String {
        value.isEmpty ? "none" : value
    }
}
