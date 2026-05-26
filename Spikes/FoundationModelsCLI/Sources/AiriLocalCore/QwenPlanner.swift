import Foundation

public struct QwenPlanner: Sendable {
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
        Supported task types:
        - calendarEvent: create or change a calendar event.
        - reminder: create or change a reminder or todo.

        For calendarEvent tasks: 
        Create one standalone instruction per calendar event that should be created or changed.
        Include the event topic/title, date, start time, end time or duration, location, participants,
        calendar hint, and notes when they are present in the original request.
        If no end time or duration is present in the original request, do not include one in the instruction.
        If the request contains alternative, optional, tentative, or backup dates, create separate
        calendarEvent tasks for them and preserve that meaning in the instruction.
        If the request contains a reason for the event, a conflict, or uncertainty, include it as notes
        inside the instruction.
        Do not invent missing details.

        Identify each task in the user request.

        Return only valid JSON in this exact format:
        {
          "tasks": [
            {
              "type": "calendarEvent|reminder",
              "instruction": "Complete standalone instruction for the next step."
            }
          ]
        }

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
        timezone: String,
        availableCalendarNames: [String] = []
    ) throws -> CalendarTaskExtraction {
        let calendarList = availableCalendarNames.isEmpty
            ? "No calendars were provided."
            : availableCalendarNames.joined(separator: ", ")
        let prompt = """
        Rules:

        If only a start time exists, set endTime to one hour after startTime and durationMinutes to 60.
        Today is \(today). Timezone is \(timezone).
        Available calendars: \(calendarList)
        If the task clearly implies one of the available calendars, set calendarName to that exact calendar name.
        If no calendar is implied, set calendarName to an empty string.
        Do not invent missing details.
        Return only valid JSON with this exact shape:
        {"type":"calendarEvent","title":"","datePhrase":"","startTime":"","endTime":"","durationMinutes":60,"location":"","people":[],"calendarName":"","notes":""}

        task:
        \(task.instruction)
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
