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
    public var notes: String
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
              Notes: \(emptyFallback(item.extraction.notes))
            """
        }
        .joined(separator: "\n")
    }

    private static func emptyFallback(_ value: String) -> String {
        value.isEmpty ? "none" : value
    }
}
