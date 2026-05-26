import Foundation

public struct CalendarEventDraft {
    public var title: String
    public var startDate: String
    public var startTime: String
    public var endTime: String
    public var durationMinutes: Int
    public var location: String
    public var participants: [String]
    public var calendarName: String
    public var notes: String
}

public enum CalendarProposalBuilder {
    public static func build(
        from extractions: [CalendarTaskExtraction],
        calendar: Calendar
    ) -> [CalendarEventDraft] {
        CalendarCapability.propose(from: extractions, calendar: calendar).map(\.draft)
    }

    public static func terminalDescription(for events: [CalendarEventDraft]) -> String {
        guard !events.isEmpty else {
            return "- none"
        }

        return events.map { event in
            let date = event.startDate.isEmpty ? "date unknown" : event.startDate
            let time = event.startTime.isEmpty ? "time unknown" : event.startTime
            let endTime = event.endTime.isEmpty ? "" : "-\(event.endTime)"
            let people = event.participants.isEmpty ? "no participants" : event.participants.joined(separator: ", ")

            var line = "- \(event.title) | \(date) \(time)\(endTime) | \(event.durationMinutes)m | \(people) | \(event.calendarName)"
            if !event.location.isEmpty {
                line += " | \(event.location)"
            }
            if !event.notes.isEmpty {
                line += " | Notes: \(event.notes)"
            }
            return line
        }
        .joined(separator: "\n")
    }
}
