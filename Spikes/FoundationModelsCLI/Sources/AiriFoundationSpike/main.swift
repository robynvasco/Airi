import Foundation
import FoundationModels

guard #available(macOS 26.0, *) else {
    print("Foundation Models requires macOS 26.0 or newer.")
    exit(0)
}

let input = CommandLine.arguments.dropFirst().joined(separator: " ")
guard !input.isEmpty else {
    print("Usage:")
    print("  swift run AiriFoundationSpike \"Plane Zahnarzt naechsten Montag um 9 und Call mit Anna Mittwoch 14 Uhr\"")
    exit(0)
}

await run(input: input)

@available(macOS 26.0, *)
private func run(input: String) async {
        let model = SystemLanguageModel.default

        print("Airi Foundation Models Spike")
        print("")
        print("Step 1 - User input")
        print(input)
        print("")

        switch model.availability {
        case .available:
            print("Step 2 - Local model")
            print("Apple Foundation Models is available on this Mac.")
        case .unavailable(let reason):
            print("Step 2 - Local model")
            print("Apple Foundation Models is not available: \(availabilityDescription(reason))")
            print("")
            print("Enable Apple Intelligence and wait for the on-device model to finish downloading, then run again.")
            return
        }
        print("")

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "de_DE")
        calendar.timeZone = .current

        let recorder = ToolCallRecorder()
        let tools: [any Tool] = [
            ResolveRelativeDateTool(recorder: recorder, calendar: calendar, referenceDate: Date()),
            FindContactCandidatesTool(recorder: recorder),
            ListCalendarsTool(recorder: recorder)
        ]

        let instructions = """
        You are the local planning core for Airi, a Mac copilot for actions.
        Convert the user's request into a calendar proposal.

        Rules:
        - Do not claim that events were created.
        - Resolve every relative date and weekday phrase with resolveRelativeDate. Never calculate dates yourself.
        - Use findContactCandidates only for people explicitly mentioned by the user.
        - Do not add Airi, the user, or the assistant as participants unless explicitly mentioned.
        - Use listCalendars once when choosing a calendar.
        - Keep titles short.
        - If a duration is missing, use 60 minutes for calls and appointments.
        - Do not ask for duration if you applied the 60 minute default.
        - If a participant name matches multiple contacts, include the candidates and add a clarification question.
        - readyForReview must be false whenever clarificationQuestions is not empty.
        - Prefer the Personal calendar unless the user indicates work.
        - Output only the requested structured CalendarBatchDraft.
        """

        let session = LanguageModelSession(
            model: model,
            tools: tools,
            instructions: instructions
        )

        let today = formattedToday(calendar: calendar)
        let tasks = TaskSplitter.split(input)
        let dateHints = resolvedDateHints(for: input, calendar: calendar)
        print("Step 3 - Local preflight")
        print("Today: \(today)")
        print("Timezone: \(TimeZone.current.identifier)")
        print("Tasks split before calling the model:")
        if tasks.isEmpty {
            print("- none")
        } else {
            for task in tasks {
                print("- Task \(task.index): \(task.text)")
            }
        }
        print("")
        print("Date hints found before calling the model:")
        if dateHints.isEmpty {
            print("- none")
        } else {
            for hint in dateHints {
                print("- \(hint.phrase) -> \(hint.isoDate)")
            }
        }
        print("")

        let prompt = """
        Today is \(today). The local timezone is \(TimeZone.current.identifier).

        Authoritative date hints from deterministic local preflight:
        \(dateHints.isEmpty ? "- none" : dateHints.map { "- \($0.phrase): \($0.isoDate)" }.joined(separator: "\n"))

        Task split from local preflight:
        \(tasks.isEmpty ? "- none" : tasks.map { "- Task \($0.index): \($0.text)" }.joined(separator: "\n"))

        Use the task split as a strong hint. Each task usually maps to one event.
        Keep names, dates, and participants attached to the task where they appear.

        User request:
        \(input)
        """

        do {
            print("Step 4 - Ask Apple Intelligence")
            print("The model receives the user input, the local date hints, the output schema, and the optional tools.")
            print("")

            let response = try await session.respond(to: prompt, schema: CalendarProposalSchema.schema)
            let toolCalls = await recorder.snapshot()
            let checks = ProposalValidator.checks(for: response.content, dateHints: dateHints)

            print("Step 5 - Tool calls")
            if toolCalls.isEmpty {
                print("- none")
            } else {
                for call in toolCalls {
                    print("- \(call)")
                }
            }
            print("")

            print(response.content.terminalCalendarProposalDescription(consistencyChecks: checks))
        } catch {
            print("")
            print("Generation failed:")
            print(String(describing: error))
        }
}

@available(macOS 26.0, *)
private func availabilityDescription(
    _ reason: SystemLanguageModel.Availability.UnavailableReason
) -> String {
    switch reason {
    case .deviceNotEligible:
        return "device not eligible"
    case .appleIntelligenceNotEnabled:
        return "Apple Intelligence not enabled"
    case .modelNotReady:
        return "model not ready"
    @unknown default:
        return "unknown"
    }
}

private func formattedToday(calendar: Calendar) -> String {
    let components = calendar.dateComponents([.year, .month, .day, .weekday], from: Date())
    let weekday = components.weekday.flatMap { weekdayName($0) } ?? "unknown weekday"

    return String(
        format: "%04d-%02d-%02d (%@)",
        components.year ?? 0,
        components.month ?? 0,
        components.day ?? 0,
        weekday
    )
}

private func weekdayName(_ weekday: Int) -> String {
    switch weekday {
    case 1: return "Sunday"
    case 2: return "Monday"
    case 3: return "Tuesday"
    case 4: return "Wednesday"
    case 5: return "Thursday"
    case 6: return "Friday"
    case 7: return "Saturday"
    default: return "unknown weekday"
    }
}

private func resolvedDateHints(for input: String, calendar: Calendar) -> [(phrase: String, isoDate: String)] {
    let normalized = input
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .lowercased()

    let resolver = DateResolver(calendar: calendar, referenceDate: Date())
    let candidates = [
        (phrase: "naechsten Montag", key: "monday"),
        (phrase: "nächsten Montag", key: "monday"),
        (phrase: "Montag", key: "monday"),
        (phrase: "Dienstag", key: "tuesday"),
        (phrase: "Mittwoch", key: "wednesday"),
        (phrase: "Donnerstag", key: "thursday"),
        (phrase: "Freitag", key: "friday"),
        (phrase: "Samstag", key: "saturday"),
        (phrase: "Sonntag", key: "sunday"),
        (phrase: "morgen", key: "tomorrow"),
        (phrase: "heute", key: "today")
    ]

    var seen: Set<String> = []
    var hints: [(phrase: String, isoDate: String)] = []

    for candidate in candidates {
        let normalizedCandidate = candidate.phrase
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        guard normalized.contains(normalizedCandidate), !seen.contains(candidate.key) else {
            continue
        }

        if let isoDate = resolver.resolve(candidate.phrase) {
            hints.append((candidate.phrase, isoDate))
            seen.insert(candidate.key)
        }
    }

    return hints
}
