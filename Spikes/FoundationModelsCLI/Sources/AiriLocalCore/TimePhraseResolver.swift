import Foundation

public struct TimePhraseResolution: Equatable {
    public enum Status: Equatable {
        case resolved
        case unresolved
    }

    public var status: Status
    public var time: String?
    public var message: String
}

public enum TimePhraseResolver {
    public static func validateClockTime(_ time: String) -> TimePhraseResolution {
        let trimmed = time.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return TimePhraseResolution(status: .unresolved, time: nil, message: "empty time")
        }

        let pattern = #"^([01]\d|2[0-3]):([0-5]\d)$"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil
        else {
            return TimePhraseResolution(status: .unresolved, time: nil, message: "time must be HH:mm")
        }

        return TimePhraseResolution(status: .resolved, time: trimmed, message: "resolved")
    }

    public static func minutesBetween(startTime: String, endTime: String) -> Int? {
        guard
            let start = minutesSinceMidnight(startTime),
            let end = minutesSinceMidnight(endTime),
            end > start
        else {
            return nil
        }

        return end - start
    }

    public static func resolve(_ phrase: String) -> TimePhraseResolution {
        let text = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return TimePhraseResolution(status: .unresolved, time: nil, message: "empty time phrase")
        }

        let patterns = [
            #"(?i)\b([01]?\d|2[0-3])[:.]([0-5]\d)\b"#,
            #"(?i)\b(?:um|at)\s+([01]?\d|2[0-3])\s*(?:uhr|h)?\b"#,
            #"(?i)\b([01]?\d|2[0-3])\s*(?:uhr|h)\b"#,
            #"(?i)\b([1-9]|1[0-2])\s*(am|pm)\b"#
        ]

        for pattern in patterns {
            guard
                let regex = try? NSRegularExpression(pattern: pattern),
                let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                let hourRange = Range(match.range(at: 1), in: text)
            else {
                continue
            }

            var hour = Int(text[hourRange]) ?? 0
            var minute = 0

            if match.numberOfRanges > 2,
               let minuteRange = Range(match.range(at: 2), in: text),
               let parsedMinute = Int(text[minuteRange]) {
                minute = parsedMinute
            }

            if match.numberOfRanges > 2,
               let meridiemRange = Range(match.range(at: 2), in: text) {
                let meridiem = text[meridiemRange].lowercased()
                if meridiem == "pm" && hour < 12 {
                    hour += 12
                }
                if meridiem == "am" && hour == 12 {
                    hour = 0
                }
            }

            return TimePhraseResolution(
                status: .resolved,
                time: String(format: "%02d:%02d", hour, minute),
                message: "resolved"
            )
        }

        return TimePhraseResolution(status: .unresolved, time: nil, message: "time phrase is not supported yet")
    }

    private static func minutesSinceMidnight(_ time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard
            parts.count == 2,
            let hour = Int(parts[0]),
            let minute = Int(parts[1]),
            (0...23).contains(hour),
            (0...59).contains(minute)
        else {
            return nil
        }

        return hour * 60 + minute
    }
}
