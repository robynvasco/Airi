import Foundation
import AiriLocalCore

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
    let planner = QwenPlanner()

    print("Step 2 - Local model")
    print("Planner: Qwen via MLX")
    print("Model path: \(planner.modelPath)")
    print("")

    let plannedTasks: [InputTask]
    let rawPlanJSON: String

    do {
        let plan = try planner.plan(input: input)
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

    print("Step 4 - Calendar field extraction")
    let calendarTasks = tasks.filter { $0.type == "calendarEvent" }
    var calendarExtractions: [CalendarTaskExtraction] = []
    var rawCalendarJSON: [String] = []

    for task in calendarTasks {
        do {
            let extraction = try planner.extractCalendarEvent(
                from: task,
                today: today,
                timezone: TimeZone.current.identifier
            )
            calendarExtractions.append(extraction)
            rawCalendarJSON.append(extraction.rawJSON)
        } catch {
            print("- Task \(task.index) extraction failed: \(String(describing: error))")
        }
    }

    print(CalendarExtractionFormatter.terminalDescription(for: calendarExtractions))
    print("")

    print("Step 5 - Deterministic local resolution")
    let toolResults = LocalToolRunner.runTools(for: calendarExtractions, calendar: calendar)
    if toolResults.isEmpty {
        print("- none")
    } else {
        for result in toolResults {
            print("- \(result.call)")
            print("  -> \(result.output.replacingOccurrences(of: "\n", with: "; "))")
        }
    }
    print("")

    print("Step 6 - Calendar capability proposals")
    let proposals = CalendarCapability.propose(from: calendarExtractions, calendar: calendar)
    let reviewBatch = CalendarReviewBatch(proposals: proposals)
    print(CalendarCapability.terminalDescription(for: reviewBatch.proposals))
    print("")
    print("Review batch:")
    print("- selected: \(reviewBatch.selectedCount)/\(reviewBatch.proposals.count)")
    print("")
    print("Nothing was written to Calendar.")

    if !rawPlanJSON.isEmpty {
        print("")
        print("Raw Qwen JSON:")
        print("Task plan:")
        print(rawPlanJSON)
        if !rawCalendarJSON.isEmpty {
            print("Calendar extractions:")
            for json in rawCalendarJSON {
                print(json)
            }
        }
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
