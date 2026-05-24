import Foundation
import FoundationModels

@available(macOS 26.0, *)
enum CalendarProposalSchema {
    static var schema: GenerationSchema {
        get throws {
            let event = DynamicGenerationSchema(
                name: "CalendarEventDraft",
                description: "A draft calendar event extracted from the user's request.",
                properties: [
                    .init(name: "title", description: "Short event title.", schema: .init(type: String.self)),
                    .init(name: "startDate", description: "Start date in YYYY-MM-DD format if known.", schema: .init(type: String.self)),
                    .init(name: "startTime", description: "Start time in HH:mm 24-hour local time, or empty for all-day events.", schema: .init(type: String.self)),
                    .init(name: "durationMinutes", description: "Duration in minutes, or 0 when unknown.", schema: .init(type: Int.self)),
                    .init(name: "isAllDay", description: "True for all-day events.", schema: .init(type: Bool.self)),
                    .init(name: "location", description: "Location, or empty when not provided.", schema: .init(type: String.self)),
                    .init(name: "participants", description: "Names of participants mentioned by the user.", schema: .init(arrayOf: .init(type: String.self), minimumElements: 0, maximumElements: 8)),
                    .init(name: "calendarName", description: "Local calendar name suggested by the listCalendars tool, or empty.", schema: .init(type: String.self)),
                    .init(name: "notes", description: "Notes about assumptions, ambiguities, or defaults.", schema: .init(type: String.self))
                ]
            )

            let question = DynamicGenerationSchema(
                name: "ClarificationQuestion",
                description: "A question that must be answered before an event can be created.",
                properties: [
                    .init(name: "id", description: "Stable short identifier, such as missing_duration_1.", schema: .init(type: String.self)),
                    .init(name: "question", description: "Question to ask the user.", schema: .init(type: String.self)),
                    .init(name: "field", description: "Field this question resolves, such as duration, contact, date, calendar, or location.", schema: .init(type: String.self))
                ]
            )

            let batch = DynamicGenerationSchema(
                name: "CalendarBatchDraft",
                description: "A reviewable batch of calendar event drafts.",
                properties: [
                    .init(name: "summary", description: "Short summary of the requested calendar changes.", schema: .init(type: String.self)),
                    .init(name: "events", description: "Event draft extracted from the current task.", schema: .init(arrayOf: .init(referenceTo: "CalendarEventDraft"), minimumElements: 1, maximumElements: 1)),
                    .init(name: "clarificationQuestions", description: "Questions to ask before creating events.", schema: .init(arrayOf: .init(referenceTo: "ClarificationQuestion"), minimumElements: 0, maximumElements: 8)),
                    .init(name: "readyForReview", description: "True only when all events are specific enough to show in a review screen.", schema: .init(type: Bool.self))
                ]
            )

            return try GenerationSchema(root: batch, dependencies: [event, question])
        }
    }
}

@available(macOS 26.0, *)
extension GeneratedContent {
    func terminalCalendarProposalDescription() -> String {
        var lines: [String] = []

        lines.append("Summary:")
        lines.append((try? value(String.self, forProperty: "summary")) ?? "No summary generated.")
        lines.append("")

        let events = (try? value([GeneratedContent].self, forProperty: "events")) ?? []
        if events.isEmpty {
            lines.append("Events: none")
        } else {
            lines.append("Events:")
            for event in events {
                let title = (try? event.value(String.self, forProperty: "title")) ?? "Untitled"
                let startDate = (try? event.value(String.self, forProperty: "startDate")) ?? ""
                let startTime = (try? event.value(String.self, forProperty: "startTime")) ?? ""
                let duration = (try? event.value(Int.self, forProperty: "durationMinutes")) ?? 0
                let isAllDay = (try? event.value(Bool.self, forProperty: "isAllDay")) ?? false
                let location = (try? event.value(String.self, forProperty: "location")) ?? ""
                let participants = (try? event.value([String].self, forProperty: "participants")) ?? []
                let calendarName = (try? event.value(String.self, forProperty: "calendarName")) ?? ""
                let notes = (try? event.value(String.self, forProperty: "notes")) ?? ""

                let datePart = isAllDay ? "\(startDate), all day" : "\(startDate) \(startTime)"
                let durationPart = duration > 0 ? "\(duration)m" : "duration unknown"
                let people = participants.isEmpty ? "no participants" : participants.joined(separator: ", ")

                lines.append("- \(title) | \(datePart) | \(durationPart) | \(people)")

                if !location.isEmpty {
                    lines.append("  Location: \(location)")
                }
                if !calendarName.isEmpty {
                    lines.append("  Calendar: \(calendarName)")
                }
                if !notes.isEmpty {
                    lines.append("  Notes: \(notes)")
                }
            }
        }

        let questions = (try? value([GeneratedContent].self, forProperty: "clarificationQuestions")) ?? []
        if !questions.isEmpty {
            lines.append("")
            lines.append("Clarification questions:")
            for question in questions {
                let field = (try? question.value(String.self, forProperty: "field")) ?? "unknown"
                let text = (try? question.value(String.self, forProperty: "question")) ?? ""
                lines.append("- [\(field)] \(text)")
            }
        }

        let ready = (try? value(Bool.self, forProperty: "readyForReview")) ?? false
        lines.append("")
        lines.append("Ready for review: \(ready ? "yes" : "no")")

        lines.append("")
        lines.append("Raw generated JSON:")
        lines.append(jsonString)

        return lines.joined(separator: "\n")
    }
}

@available(macOS 26.0, *)
enum ProposalSanitizer {
    static func sanitizedCalendarDescription(for result: TaskModelResult) -> String {
        let explicitPeople = Set(PeopleExtractor.explicitPeople(in: result.task))
        var lines: [String] = []

        lines.append("Sanitized proposal:")
        lines.append("Participants are controlled by Airi preflight, not free model output.")

        let events = (try? result.content.value([GeneratedContent].self, forProperty: "events")) ?? []
        if events.isEmpty {
            lines.append("- no event")
            return lines.joined(separator: "\n")
        }

        for event in events {
            let title = (try? event.value(String.self, forProperty: "title")) ?? "Untitled"
            let startDate = (try? event.value(String.self, forProperty: "startDate")) ?? ""
            let startTime = (try? event.value(String.self, forProperty: "startTime")) ?? ""
            let duration = (try? event.value(Int.self, forProperty: "durationMinutes")) ?? 0
            let isAllDay = (try? event.value(Bool.self, forProperty: "isAllDay")) ?? false
            let participants = explicitPeople.sorted()
            let datePart = isAllDay ? "\(startDate), all day" : "\(startDate) \(startTime)"
            let durationPart = duration > 0 ? "\(duration)m" : "duration unknown"
            let people = participants.isEmpty ? "no participants" : participants.joined(separator: ", ")

            lines.append("- \(title) | \(datePart) | \(durationPart) | \(people)")
        }

        return lines.joined(separator: "\n")
    }
}

@available(macOS 26.0, *)
struct TaskModelResult {
    var task: InputTask
    var content: GeneratedContent
}

@available(macOS 26.0, *)
enum ProposalValidator {
    static func checks(for results: [TaskModelResult], dateHints: [(phrase: String, isoDate: String)]) -> [String] {
        var checks: [String] = []

        for result in results {
            let readyForReview = (try? result.content.value(Bool.self, forProperty: "readyForReview")) ?? false
            let questions = (try? result.content.value([GeneratedContent].self, forProperty: "clarificationQuestions")) ?? []
            let explicitPeople = Set(PeopleExtractor.explicitPeople(in: result.task))
            let events = (try? result.content.value([GeneratedContent].self, forProperty: "events")) ?? []

            if readyForReview && !questions.isEmpty {
                checks.append("Task \(result.task.index) says it is ready, but it still contains clarification questions.")
            }

            if !readyForReview && questions.isEmpty {
                checks.append("Task \(result.task.index) says it is not ready, but it does not explain what needs clarification.")
            }

            for event in events {
                let participants = (try? event.value([String].self, forProperty: "participants")) ?? []
                for participant in participants where !participantIsAllowed(participant, explicitPeople: explicitPeople) {
                    checks.append("Task \(result.task.index) produced participant '\(participant)', but that person was not explicitly found in the task.")
                }
            }
        }

        let eventDates = Set(results.flatMap { result in
            ((try? result.content.value([GeneratedContent].self, forProperty: "events")) ?? [])
                .compactMap { try? $0.value(String.self, forProperty: "startDate") }
        })

        for hint in dateHints where !eventDates.contains(hint.isoDate) {
            checks.append("The local date hint '\(hint.phrase) -> \(hint.isoDate)' does not appear in the generated event dates.")
        }

        return checks
    }

    private static func participantIsAllowed(_ participant: String, explicitPeople: Set<String>) -> Bool {
        let normalizedParticipant = participant
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        return explicitPeople.contains { person in
            let normalizedPerson = person
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()

            return normalizedParticipant.contains(normalizedPerson)
        }
    }
}
