import Foundation

public struct QwenPlanner {
    public var modelPath: String
    public var executablePath: String

    public init(
        modelPath: String = ProcessInfo.processInfo.environment["AIRI_QWEN_MODEL_PATH"]
            ?? "/Users/robyn/.lmstudio/models/mlx-community/Qwen3.5-9B-MLX-4bit",
        executablePath: String = ProcessInfo.processInfo.environment["AIRI_MLX_GENERATE_PATH"]
            ?? "/Users/robyn/Library/Python/3.11/bin/mlx_lm.generate"
    ) {
        self.modelPath = modelPath
        self.executablePath = executablePath
    }

    public func plan(input: String) throws -> (tasks: [InputTask], rawJSON: String) {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw QwenPlannerError.missingExecutable(executablePath)
        }

        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw QwenPlannerError.missingModel(modelPath)
        }

        let prompt = """
        Split the user request into independent USER ACTIONS, not internal tool steps.
        Keep each task text close to the user's words.

        Schema:
        {"tasks":[{"text":string,"type":"calendarEvent|reminder|note|file|app|clipboard|unknown"}]}

        Classification rules:
        - A task with a date or weekday and a time is a calendarEvent unless the user explicitly says reminder.
        - Calls, meetings, appointments, Termine, Zahnarzt, Arzt, and events with a time belong to calendarEvent.
        - Use reminder only when the user asks to be reminded or to add a todo.

        User request:
        \(input)
        """

        let json = try strictJSON(from: try runMLX(prompt: prompt))
        let plan = try decode(TaskPlan.self, from: json)
        return (TaskPlanParser.inputTasks(from: plan), json)
    }

    public func extractCalendarEvent(
        from task: InputTask,
        today: String,
        timezone: String
    ) throws -> CalendarTaskExtraction {
        let prompt = """
        Extract calendar fields from this one task.

        Context:
        - Today: \(today)
        - Timezone: \(timezone)

        Return this exact schema:
        {"type":"calendarEvent","title":string,"datePhrase":string,"timePhrase":string,"people":[string]}

        Rules:
        - title is the calendar event title, not the full command.
        - Remove command words such as Plane, Bitte plane, Schedule, Create, Put.
        - Remove date and time phrases from title.
        - Keep datePhrase as the user's wording, such as "Mittwoch", "next Monday", or "morgen".
        - Do not calculate the final date.
        - Keep timePhrase as the user's wording, such as "14 Uhr", "2pm", or "um 9".
        - People must include only people explicitly mentioned in this task.
        - Do not add the user, assistant, or app as people.
        - If a field is missing, use an empty string or an empty array.

        Task:
        \(task.text)
        """

        let json = try strictJSON(from: try runMLX(prompt: prompt))
        let extraction = try decode(CalendarExtraction.self, from: json)
        return CalendarTaskExtraction(task: task, extraction: extraction, rawJSON: json)
    }

    private func runMLX(prompt: String) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = [
            "--model", modelPath,
            "--max-tokens", "800",
            "--temp", "0.0",
            "--verbose", "false",
            "--chat-template-config", #"{"enable_thinking": false}"#,
            "--system-prompt", "You output only valid JSON. No explanations. No markdown.",
            "--prompt", prompt
        ]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw QwenPlannerError.generationFailed(error.isEmpty ? output : error)
        }

        return output
    }

    private func strictJSON(from output: String) throws -> String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"), trimmed.hasSuffix("}") else {
            throw QwenPlannerError.invalidJSON(output)
        }

        return trimmed
    }

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: Data(json.utf8))
        } catch {
            throw QwenPlannerError.invalidJSON(json)
        }
    }
}

public enum QwenPlannerError: Error, CustomStringConvertible {
    case missingExecutable(String)
    case missingModel(String)
    case generationFailed(String)
    case invalidJSON(String)

    public var description: String {
        switch self {
        case .missingExecutable(let path):
            return "MLX generator not found or not executable: \(path)"
        case .missingModel(let path):
            return "Qwen model not found: \(path)"
        case .generationFailed(let message):
            return "Qwen generation failed: \(message)"
        case .invalidJSON(let output):
            return "Qwen did not return valid JSON: \(output)"
        }
    }
}
