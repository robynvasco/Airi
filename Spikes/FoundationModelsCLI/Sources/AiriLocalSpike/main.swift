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

    let planner = QwenPlanner()
    let result = LocalPlanningPipeline(planner: planner).run(input: input)

    print("Step 2 - Local model")
    print("Planner: Qwen via MLX")
    print("Model path: \(result.modelPath)")
    print("")

    if let planningError = result.planningError {
        print("Qwen planning failed, using simple fallback splitter:")
        print(planningError)
        print("")
    }

    print("Step 3 - Local preflight")
    print("Today: \(result.today)")
    print("Timezone: \(result.timezone)")
    print("")
    print("Tasks:")
    print(TaskPlanParser.terminalDescription(for: result.tasks))
    print("")

    print("Step 4 - Calendar field extraction")
    for error in result.extractionErrors {
        print("- \(error)")
    }
    print(CalendarExtractionFormatter.terminalDescription(for: result.calendarExtractions))
    print("")

    print("Step 5 - Deterministic local resolution")
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "de_DE")
    calendar.timeZone = .current
    let toolResults = LocalToolRunner.runTools(
        for: result.calendarExtractions,
        calendar: calendar,
        availableCalendarNames: result.availableCalendarNames
    )
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
    print(CalendarCapability.terminalDescription(for: result.reviewBatch.proposals))
    print("")
    print("Review batch:")
    print("- selected: \(result.reviewBatch.selectedCount)/\(result.reviewBatch.proposals.count)")
    print("")
    print("Nothing was written to Calendar.")

    if !result.rawPlanJSON.isEmpty {
        print("")
        print("Raw Qwen JSON:")
        print("Task plan:")
        print(result.rawPlanJSON)
        if !result.rawCalendarJSON.isEmpty {
            print("Calendar extractions:")
            for json in result.rawCalendarJSON {
                print(json)
            }
        }
    }
}
