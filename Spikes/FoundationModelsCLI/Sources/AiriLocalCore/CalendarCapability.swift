import Foundation

public struct ClarificationQuestion: Equatable {
    public var field: String
    public var question: String
}

public struct CalendarProposal {
    public enum Status: Equatable {
        case ready
        case needsClarification
    }

    public var draft: CalendarEventDraft
    public var status: Status
    public var clarificationQuestions: [ClarificationQuestion]
}

public enum CalendarCapability {
    public static func propose(
        from extractions: [CalendarTaskExtraction],
        calendar: Calendar,
        referenceDate: Date = Date()
    ) -> [CalendarProposal] {
        let dateResolver = DatePhraseResolver(calendar: calendar, referenceDate: referenceDate)

        return extractions.map { item in
            let extraction = item.extraction
            let dateResolution = dateResolver.resolve(extraction.datePhrase)
            let timeResolution = TimePhraseResolver.resolve(extraction.timePhrase)
            var questions: [ClarificationQuestion] = []

            if extraction.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                questions.append(
                    ClarificationQuestion(
                        field: "title",
                        question: "Wie soll der Termin heißen?"
                    )
                )
            }

            switch dateResolution.status {
            case .resolved:
                break
            case .ambiguous:
                questions.append(
                    ClarificationQuestion(
                        field: "date",
                        question: "Das Datum \"\(extraction.datePhrase)\" ist uneindeutig: \(dateResolution.message). Welches Datum meinst du?"
                    )
                )
            case .unresolved:
                questions.append(
                    ClarificationQuestion(
                        field: "date",
                        question: "Ich konnte das Datum \"\(extraction.datePhrase)\" nicht sicher auflösen: \(dateResolution.message). Welches Datum meinst du?"
                    )
                )
            }

            if timeResolution.status != .resolved {
                questions.append(
                    ClarificationQuestion(
                        field: "time",
                        question: "Welche Uhrzeit meinst du?"
                    )
                )
            }

            let draft = CalendarEventDraft(
                title: extraction.title,
                startDate: dateResolution.isoDate ?? "",
                startTime: timeResolution.time ?? "",
                durationMinutes: 60,
                participants: extraction.people,
                calendarName: "Personal"
            )

            return CalendarProposal(
                draft: draft,
                status: questions.isEmpty ? .ready : .needsClarification,
                clarificationQuestions: questions
            )
        }
    }

    public static func terminalDescription(for proposals: [CalendarProposal]) -> String {
        guard !proposals.isEmpty else {
            return "- none"
        }

        return proposals.map { proposal in
            var lines: [String] = []
            let event = proposal.draft
            let date = event.startDate.isEmpty ? "date unknown" : event.startDate
            let time = event.startTime.isEmpty ? "time unknown" : event.startTime
            let people = event.participants.isEmpty ? "no participants" : event.participants.joined(separator: ", ")

            lines.append("- \(event.title) | \(date) \(time) | \(event.durationMinutes)m | \(people) | \(event.calendarName)")
            lines.append("  Status: \(proposal.status == .ready ? "ready" : "needs clarification")")

            for question in proposal.clarificationQuestions {
                lines.append("  Clarification [\(question.field)]: \(question.question)")
            }

            return lines.joined(separator: "\n")
        }
        .joined(separator: "\n")
    }
}
