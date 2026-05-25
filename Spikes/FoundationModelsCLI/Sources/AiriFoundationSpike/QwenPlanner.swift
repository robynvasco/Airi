import Foundation

struct QwenPlanner {
    var modelPath: String
    var executablePath: String

    init(
        modelPath: String = ProcessInfo.processInfo.environment["AIRI_QWEN_MODEL_PATH"]
            ?? "/Users/robyn/.lmstudio/models/mlx-community/Qwen3.5-9B-MLX-4bit",
        executablePath: String = ProcessInfo.processInfo.environment["AIRI_MLX_GENERATE_PATH"]
            ?? "/Users/robyn/Library/Python/3.11/bin/mlx_lm.generate"
    ) {
        self.modelPath = modelPath
        self.executablePath = executablePath
    }

    func plan(input: String) throws -> (tasks: [InputTask], rawJSON: String) {
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
        {"tasks":[{"text":string,"type":"calendarEvent|reminder|note|file|app|clipboard|unknown","suggestedTools":[string]}]}

        Available tools:
        - resolveRelativeDate: use for relative dates or weekdays
        - findContactCandidates: use for named people
        - listCalendars: use for calendar events

        Classification rules:
        - A task with a date or weekday and a time is a calendarEvent unless the user explicitly says reminder.
        - Calls, meetings, appointments, Termine, Zahnarzt, Arzt, and events with a time belong to calendarEvent.
        - Use reminder only when the user asks to be reminded or to add a todo.

        User request:
        \(input)
        """

        let result = try runMLX(prompt: prompt)
        let candidates = extractJSONObjects(from: result)

        for json in candidates.reversed() {
            if let plan = try? JSONDecoder().decode(TaskPlan.self, from: Data(json.utf8)) {
                return (TaskPlanParser.inputTasks(from: plan), json)
            }
        }

        if let repaired = repairTrailingBraces(in: result),
           let plan = try? JSONDecoder().decode(TaskPlan.self, from: Data(repaired.utf8)) {
            return (TaskPlanParser.inputTasks(from: plan), repaired)
        }

        throw QwenPlannerError.invalidJSON(result)
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

    private func extractJSONObjects(from output: String) -> [String] {
        var candidates: [String] = []
        var depth = 0
        var start: String.Index?

        for index in output.indices {
            let character = output[index]

            if character == "{" {
                if depth == 0 {
                    start = index
                }
                depth += 1
            }

            if character == "}" {
                depth -= 1
                if depth == 0, let startIndex = start {
                    candidates.append(String(output[startIndex...index]))
                    start = nil
                }
            }
        }

        return candidates
    }

    private func repairTrailingBraces(in output: String) -> String? {
        guard let start = output.firstIndex(of: "{") else {
            return nil
        }

        var json = String(output[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let openBraces = json.filter { $0 == "{" }.count
        let closeBraces = json.filter { $0 == "}" }.count

        guard openBraces > closeBraces else {
            return nil
        }

        json += String(repeating: "}", count: openBraces - closeBraces)
        return json
    }
}

enum QwenPlannerError: Error, CustomStringConvertible {
    case missingExecutable(String)
    case missingModel(String)
    case generationFailed(String)
    case invalidJSON(String)

    var description: String {
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
