import Foundation

struct CalendarEventDraft {
    var title: String
    var startDate: String
    var startTime: String
    var durationMinutes: Int
    var participants: [String]
    var calendarName: String
}

enum CalendarProposalBuilder {
    static func build(
        from tasks: [InputTask],
        dateHints: [(phrase: String, isoDate: String)]
    ) -> [CalendarEventDraft] {
        tasks
            .filter { $0.type == "calendarEvent" }
            .map { task in
                let taskHints = dateHintsForTask(task, dateHints: dateHints)
                return CalendarEventDraft(
                    title: title(from: task.text),
                    startDate: taskHints.first?.isoDate ?? "",
                    startTime: time(from: task.text) ?? "",
                    durationMinutes: 60,
                    participants: PeopleExtractor.explicitPeople(in: task),
                    calendarName: "Personal"
                )
            }
    }

    static func terminalDescription(for events: [CalendarEventDraft]) -> String {
        guard !events.isEmpty else {
            return "- none"
        }

        return events.map { event in
            let date = event.startDate.isEmpty ? "date unknown" : event.startDate
            let time = event.startTime.isEmpty ? "time unknown" : event.startTime
            let people = event.participants.isEmpty ? "no participants" : event.participants.joined(separator: ", ")

            return "- \(event.title) | \(date) \(time) | \(event.durationMinutes)m | \(people) | \(event.calendarName)"
        }
        .joined(separator: "\n")
    }

    private static func title(from text: String) -> String {
        var title = text
        let prefixes = [
            "Plane ",
            "Bitte plane ",
            "Put ",
            "Schedule ",
            "Create "
        ]

        for prefix in prefixes where title.hasPrefix(prefix) {
            title = String(title.dropFirst(prefix.count))
        }

        let cutMarkers = [
            " am ",
            " um ",
            " at ",
            " on ",
            " next ",
            " nächsten ",
            " naechsten ",
            " Monday",
            " Montag",
            " Tuesday",
            " Dienstag",
            " Wednesday",
            " Mittwoch",
            " Thursday",
            " Donnerstag",
            " Friday",
            " Freitag",
            " Saturday",
            " Samstag",
            " Sunday",
            " Sonntag"
        ]

        for marker in cutMarkers {
            if let range = title.range(of: marker, options: [.caseInsensitive]) {
                title = String(title[..<range.lowerBound])
            }
        }

        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func time(from text: String) -> String? {
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

            return String(format: "%02d:%02d", hour, minute)
        }

        return nil
    }
}

func dateHintsForTask(
    _ task: InputTask,
    dateHints: [(phrase: String, isoDate: String)]
) -> [(phrase: String, isoDate: String)] {
    let normalizedTask = task.text
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .lowercased()

    return dateHints.filter { hint in
        let normalizedPhrase = hint.phrase
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        return normalizedTask.contains(normalizedPhrase)
    }
}
