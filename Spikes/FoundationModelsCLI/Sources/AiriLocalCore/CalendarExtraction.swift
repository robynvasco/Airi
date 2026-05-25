import Foundation

public struct CalendarExtraction: Decodable {
    public var type: String
    public var title: String
    public var datePhrase: String
    public var timePhrase: String
    public var people: [String]
}

public struct CalendarTaskExtraction {
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
              Time phrase: \(emptyFallback(item.extraction.timePhrase))
              People: \(people)
            """
        }
        .joined(separator: "\n")
    }

    private static func emptyFallback(_ value: String) -> String {
        value.isEmpty ? "none" : value
    }
}
