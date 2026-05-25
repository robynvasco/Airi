import Foundation

public struct TaskPlan: Decodable {
    public var tasks: [PlannedTask]
}

public struct PlannedTask: Decodable {
    public var text: String
    public var type: String
}

public enum TaskPlanParser {
    public static func inputTasks(from plan: TaskPlan) -> [InputTask] {
        plan.tasks.enumerated().map { offset, task in
            InputTask(
                index: offset + 1,
                text: task.text,
                source: .model,
                type: task.type,
                reason: "Qwen planner"
            )
        }
    }

    public static func terminalDescription(for tasks: [InputTask]) -> String {
        var lines: [String] = []

        if tasks.isEmpty {
            lines.append("- none")
            return lines.joined(separator: "\n")
        }

        for task in tasks {
            lines.append("- Task \(task.index): \(task.text)")
            lines.append("  Type: \(task.type)")
            if !task.reason.isEmpty {
                lines.append("  Reason: \(task.reason)")
            }
        }

        return lines.joined(separator: "\n")
    }
}
