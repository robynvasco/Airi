import Foundation

public struct LocalPlanningResult: Sendable {
    public var input: String
    public var today: String
    public var timezone: String
    public var modelPath: String
    public var availableCalendarNames: [String]
    public var tasks: [InputTask]
    public var calendarExtractions: [CalendarTaskExtraction]
    public var reviewBatch: CalendarReviewBatch
    public var planningError: String?
    public var extractionErrors: [String]
    public var rawPlanJSON: String
    public var rawCalendarJSON: [String]
}

public struct LocalPlanningPipeline: Sendable {
    public var planner: QwenPlanner

    public init(planner: QwenPlanner = QwenPlanner()) {
        self.planner = planner
    }

    public func run(
        input: String,
        referenceDate: Date = Date(),
        availableCalendarNames: [String] = []
    ) -> LocalPlanningResult {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "de_DE")
        calendar.timeZone = .current

        let today = Self.formattedToday(referenceDate, calendar: calendar)
        let timezone = TimeZone.current.identifier

        let plannedTasks: [InputTask]
        let rawPlanJSON: String
        let planningError: String?

        do {
            let plan = try planner.plan(input: input)
            plannedTasks = plan.tasks
            rawPlanJSON = plan.rawJSON
            planningError = nil
        } catch {
            plannedTasks = TaskSplitter.split(input)
            rawPlanJSON = ""
            planningError = String(describing: error)
        }

        let tasks = plannedTasks.isEmpty ? TaskSplitter.split(input) : plannedTasks
        let calendarTasks = tasks.filter { $0.type == "calendarEvent" }
        var calendarExtractions: [CalendarTaskExtraction] = []
        var rawCalendarJSON: [String] = []
        var extractionErrors: [String] = []

        for task in calendarTasks {
            do {
                let extraction = try planner.extractCalendarEvent(
                    from: task,
                    today: today,
                    timezone: timezone,
                    availableCalendarNames: availableCalendarNames
                )
                calendarExtractions.append(extraction)
                rawCalendarJSON.append(extraction.rawJSON)
            } catch {
                extractionErrors.append("Task \(task.index): \(String(describing: error))")
            }
        }

        let proposals = CalendarCapability.propose(
            from: calendarExtractions,
            calendar: calendar,
            referenceDate: referenceDate,
            availableCalendarNames: availableCalendarNames
        )

        return LocalPlanningResult(
            input: input,
            today: today,
            timezone: timezone,
            modelPath: planner.modelPath,
            availableCalendarNames: availableCalendarNames,
            tasks: tasks,
            calendarExtractions: calendarExtractions,
            reviewBatch: CalendarReviewBatch(proposals: proposals),
            planningError: planningError,
            extractionErrors: extractionErrors,
            rawPlanJSON: rawPlanJSON,
            rawCalendarJSON: rawCalendarJSON
        )
    }

    public static func formattedToday(_ date: Date = Date(), calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
        let weekday = components.weekday.flatMap { weekdayName($0) } ?? "unknown weekday"

        return String(
            format: "%04d-%02d-%02d (%@)",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
            weekday
        )
    }

    private static func weekdayName(_ weekday: Int) -> String {
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
}
