import Foundation

struct TaskPlan: Decodable {
    var tasks: [PlannedTask]
}

struct PlannedTask: Decodable {
    var text: String
    var type: String
}

enum TaskPlanParser {
    static func inputTasks(from plan: TaskPlan) -> [InputTask] {
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

    static func terminalDescription(for tasks: [InputTask]) -> String {
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
