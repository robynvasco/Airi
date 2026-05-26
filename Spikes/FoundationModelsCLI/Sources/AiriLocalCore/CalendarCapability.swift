import Foundation

public struct CalendarProposalWarning: Equatable {
    public var field: String
    public var message: String
}

public struct CalendarProposal {
    public enum ReviewStatus: Equatable {
        case ready
        case needsReview
    }

    public var draft: CalendarEventDraft
    public var reviewStatus: ReviewStatus
    public var warnings: [CalendarProposalWarning]
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

            let draft = CalendarEventDraft(
                title: extraction.title,
                startDate: dateResolution.isoDate ?? "",
                startTime: startTimeResolution.time ?? "",
                endTime: endTimeResolution.time ?? "",
                durationMinutes: calculatedDuration ?? extraction.durationMinutes,
                location: extraction.location,
                participants: extraction.people,
                calendarName: "Personal",
                notes: extraction.notes
            )

            return CalendarProposal(
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

            var eventLine = "- \(event.title) | \(date) \(time)\(endTime) | \(event.durationMinutes)m | \(people) | \(event.calendarName)"
            if !event.location.isEmpty {
                eventLine += " | \(event.location)"
            }
            lines.append(eventLine)
            lines.append("  Review: \(proposal.reviewStatus == .ready ? "ready" : "needs review")")
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
}
