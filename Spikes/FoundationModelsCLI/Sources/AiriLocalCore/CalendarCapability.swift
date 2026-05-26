import Foundation

public struct CalendarProposalWarning: Equatable, Sendable {
    public var field: String
    public var message: String

    public init(field: String, message: String) {
        self.field = field
        self.message = message
    }
}

public struct CalendarProposal: Sendable {
    public enum ReviewStatus: Equatable, Sendable {
        case ready
        case needsReview
    }

    public var id: String
    public var isSelected: Bool
    public var sourceInstruction: String
    public var draft: CalendarEventDraft
    public var reviewStatus: ReviewStatus
    public var warnings: [CalendarProposalWarning]

    public init(
        id: String,
        isSelected: Bool,
        sourceInstruction: String,
        draft: CalendarEventDraft,
        reviewStatus: ReviewStatus,
        warnings: [CalendarProposalWarning]
    ) {
        self.id = id
        self.isSelected = isSelected
        self.sourceInstruction = sourceInstruction
        self.draft = draft
        self.reviewStatus = reviewStatus
        self.warnings = warnings
    }
}

public enum CalendarCapability {
    public static func propose(
        from extractions: [CalendarTaskExtraction],
        calendar: Calendar,
        referenceDate: Date = Date(),
        availableCalendarNames: [String] = []
    ) -> [CalendarProposal] {
        let dateResolver = DatePhraseResolver(calendar: calendar, referenceDate: referenceDate)
        let defaultCalendarName = availableCalendarNames.first ?? ""

        return extractions.map { item in
            let extraction = item.extraction
            let dateResolution = dateResolver.resolve(extraction.datePhrase)
            let startTimeResolution = TimePhraseResolver.validateClockTime(extraction.startTime)
            let endTimeResolution = TimePhraseResolver.validateClockTime(extraction.endTime)
            let calculatedDuration = TimePhraseResolver.minutesBetween(
                startTime: extraction.startTime,
                endTime: extraction.endTime
            )
            var warnings: [CalendarProposalWarning] = []

            if extraction.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                warnings.append(
                    CalendarProposalWarning(
                        field: "title",
                        message: "Der Termin hat keinen Titel."
                    )
                )
            }

            switch dateResolution.status {
            case .resolved:
                break
            case .ambiguous:
                warnings.append(
                    CalendarProposalWarning(
                        field: "date",
                        message: "Das Datum \"\(extraction.datePhrase)\" ist uneindeutig: \(dateResolution.message)."
                    )
                )
            case .unresolved:
                warnings.append(
                    CalendarProposalWarning(
                        field: "date",
                        message: "Das Datum \"\(extraction.datePhrase)\" konnte nicht sicher aufgelöst werden: \(dateResolution.message)."
                    )
                )
            }

            if startTimeResolution.status != .resolved {
                warnings.append(
                    CalendarProposalWarning(
                        field: "time",
                        message: "Die Startzeit ist ungültig oder fehlt."
                    )
                )
            }

            if endTimeResolution.status != .resolved {
                warnings.append(
                    CalendarProposalWarning(
                        field: "endTime",
                        message: "Die Endzeit ist ungültig oder fehlt."
                    )
                )
            } else if calculatedDuration == nil {
                warnings.append(
                    CalendarProposalWarning(
                        field: "duration",
                        message: "Die Endzeit liegt nicht nach der Startzeit."
                    )
                )
            }

            if !availableCalendarNames.isEmpty && extraction.calendarName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                warnings.append(
                    CalendarProposalWarning(
                        field: "calendar",
                        message: "Es wurde kein Kalender aus der Eingabe erkannt."
                    )
                )
            } else if !availableCalendarNames.isEmpty && !availableCalendarNames.contains(extraction.calendarName) {
                warnings.append(
                    CalendarProposalWarning(
                        field: "calendar",
                        message: "Der Kalender \"\(extraction.calendarName)\" wurde nicht in den macOS-Kalendern gefunden."
                    )
                )
            }

            let draft = CalendarEventDraft(
                title: extraction.title,
                startDate: dateResolution.isoDate ?? "",
                startTime: startTimeResolution.time ?? "",
                endTime: endTimeResolution.time ?? "",
                durationMinutes: calculatedDuration ?? extraction.durationMinutes,
                location: extraction.location,
                participants: extraction.people,
                calendarName: extraction.calendarName.isEmpty ? defaultCalendarName : extraction.calendarName,
                notes: extraction.notes
            )

            return CalendarProposal(
                id: proposalID(for: item),
                isSelected: true,
                sourceInstruction: item.task.instruction,
                draft: draft,
                reviewStatus: warnings.isEmpty ? .ready : .needsReview,
                warnings: warnings
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
            let endTime = event.endTime.isEmpty ? "" : "-\(event.endTime)"
            let people = event.participants.isEmpty ? "no participants" : event.participants.joined(separator: ", ")
            let calendarName = event.calendarName.isEmpty ? "calendar unknown" : event.calendarName
            let selection = proposal.isSelected ? "[x]" : "[ ]"

            var eventLine = "- \(selection) \(event.title) | \(date) \(time)\(endTime) | \(event.durationMinutes)m | \(people) | \(calendarName)"
            if !event.location.isEmpty {
                eventLine += " | \(event.location)"
            }
            lines.append(eventLine)
            lines.append("  ID: \(proposal.id)")
            lines.append("  Review: \(proposal.reviewStatus == .ready ? "ready" : "needs review")")
            lines.append("  Source: \(proposal.sourceInstruction)")
            if !event.notes.isEmpty {
                lines.append("  Notes: \(event.notes)")
            }

            for warning in proposal.warnings {
                lines.append("  Warning [\(warning.field)]: \(warning.message)")
            }

            return lines.joined(separator: "\n")
        }
        .joined(separator: "\n")
    }

    private static func proposalID(for item: CalendarTaskExtraction) -> String {
        "calendar-\(item.task.index)"
    }
}
