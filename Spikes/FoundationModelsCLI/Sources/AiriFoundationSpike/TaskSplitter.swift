import Foundation

struct InputTask {
    enum Source {
        case model
        case fallback
    }

    var index: Int
    var text: String
    var source: Source = .fallback
    var type: String = "calendarEvent"
    var suggestedTools: [String] = []
    var reason: String = ""
}

enum TaskSplitter {
    static func split(_ input: String) -> [InputTask] {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return []
        }

        let roughParts = normalized
            .replacingOccurrences(of: ",", with: " und ")
            .components(separatedBy: " und ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let parts = roughParts.isEmpty ? [normalized] : roughParts

        return parts.enumerated().map { offset, text in
            InputTask(
                index: offset + 1,
                text: cleanTaskPrefix(text, isFirst: offset == 0),
                source: .fallback,
                type: "calendarEvent",
                suggestedTools: [],
                reason: "Fallback splitter"
            )
        }
    }

    private static func cleanTaskPrefix(_ text: String, isFirst: Bool) -> String {
        guard isFirst else {
            return text
        }

        let prefixes = [
            "Plane ",
            "Bitte plane ",
            "Erstelle ",
            "Bitte erstelle ",
            "Create ",
            "Schedule "
        ]

        for prefix in prefixes where text.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return text
    }
}
