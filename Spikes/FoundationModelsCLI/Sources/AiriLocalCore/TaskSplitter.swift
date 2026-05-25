import Foundation

public struct InputTask {
    public enum Source {
        case model
        case fallback
    }

    public var index: Int
    public var text: String
    public var source: Source
    public var type: String
    public var reason: String

    public init(
        index: Int,
        text: String,
        source: Source = .fallback,
        type: String = "calendarEvent",
        reason: String = ""
    ) {
        self.index = index
        self.text = text
        self.source = source
        self.type = type
        self.reason = reason
    }
}

public enum TaskSplitter {
    public static func split(_ input: String) -> [InputTask] {
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
