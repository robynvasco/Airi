import Foundation

let input = CommandLine.arguments.dropFirst().joined(separator: " ")
guard !input.isEmpty else {
    print("Usage:")
    print("  swift run AiriLocalSpike \"Plane Zahnarzt naechsten Montag um 9 und Call mit Anna Mittwoch 14 Uhr\"")
    exit(0)
}

run(input: input)

private func run(input: String) {
    print("Airi Local Qwen Spike")
    print("")
    print("Step 1 - User input")
    print(input)
    print("")

    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "de_DE")
    calendar.timeZone = .current

    let today = formattedToday(calendar: calendar)
    let dateHints = resolvedDateHints(for: input, calendar: calendar)

    print("Step 2 - Local model")
    print("Planner: Qwen via MLX")
    print("Model path: \(QwenPlanner().modelPath)")
    print("")

    let plannedTasks: [InputTask]
    let rawPlanJSON: String

    do {
        let plan = try QwenPlanner().plan(input: input)
        plannedTasks = plan.tasks
        rawPlanJSON = plan.rawJSON
    } catch {
        plannedTasks = TaskSplitter.split(input)
        rawPlanJSON = ""
        print("Qwen planning failed, using simple fallback splitter:")
        print(String(describing: error))
        print("")
    }

    let tasks = plannedTasks.isEmpty ? TaskSplitter.split(input) : plannedTasks

    print("Step 3 - Local preflight")
    print("Today: \(today)")
    print("Timezone: \(TimeZone.current.identifier)")
    print("")
    print("Tasks:")
    print(TaskPlanParser.terminalDescription(for: tasks))
    print("")
    print("Date hints:")
    if dateHints.isEmpty {
        print("- none")
    } else {
        for hint in dateHints {
            print("- \(hint.phrase) -> \(hint.isoDate)")
        }
    }
    print("")

    print("Step 4 - Local tool simulation")
    let toolResults = LocalToolRunner.runTools(for: tasks, dateHints: dateHints)
    if toolResults.isEmpty {
        print("- none")
    } else {
        for result in toolResults {
            print("- \(result.call)")
            print("  -> \(result.output.replacingOccurrences(of: "\n", with: "; "))")
        }
    }
    print("")

    print("Step 5 - Draft proposals")
    let events = CalendarProposalBuilder.build(from: tasks, dateHints: dateHints)
    print(CalendarProposalBuilder.terminalDescription(for: events))
    print("")
    print("Nothing was written to Calendar.")

    if !rawPlanJSON.isEmpty {
        print("")
        print("Raw Qwen JSON:")
        print(rawPlanJSON)
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
        (phrase: "next Monday", key: "monday"),
        (phrase: "naechsten Montag", key: "monday"),
        (phrase: "nächsten Montag", key: "monday"),
        (phrase: "Monday", key: "monday"),
        (phrase: "Montag", key: "monday"),
        (phrase: "Tuesday", key: "tuesday"),
        (phrase: "Dienstag", key: "tuesday"),
        (phrase: "Wednesday", key: "wednesday"),
        (phrase: "Mittwoch", key: "wednesday"),
        (phrase: "Thursday", key: "thursday"),
        (phrase: "Donnerstag", key: "thursday"),
        (phrase: "Friday", key: "friday"),
        (phrase: "Freitag", key: "friday"),
        (phrase: "Saturday", key: "saturday"),
        (phrase: "Samstag", key: "saturday"),
        (phrase: "Sunday", key: "sunday"),
        (phrase: "Sonntag", key: "sunday"),
        (phrase: "tomorrow", key: "tomorrow"),
        (phrase: "morgen", key: "tomorrow"),
        (phrase: "today", key: "today"),
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
