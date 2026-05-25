import Foundation

struct CalendarExtraction: Decodable {
    var type: String
    var title: String
    var datePhrase: String
    var timePhrase: String
    var people: [String]
}

struct CalendarTaskExtraction {
    var task: InputTask
    var extraction: CalendarExtraction
    var rawJSON: String
}

enum CalendarExtractionFormatter {
    static func terminalDescription(for extractions: [CalendarTaskExtraction]) -> String {
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
