import Foundation

struct TaskPlan: Decodable {
    var tasks: [PlannedTask]
}

struct PlannedTask: Decodable {
    var text: String
    var type: String
    var suggestedTools: [String]
}

enum TaskPlanParser {
    static func inputTasks(from plan: TaskPlan) -> [InputTask] {
        plan.tasks.enumerated().map { offset, task in
            InputTask(
                index: offset + 1,
                text: task.text,
                source: .model,
                type: task.type,
                suggestedTools: task.suggestedTools,
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
            lines.append("  Suggested tools: \(task.suggestedTools.isEmpty ? "none" : task.suggestedTools.joined(separator: ", "))")
            if !task.reason.isEmpty {
                lines.append("  Reason: \(task.reason)")
            }
        }

        return lines.joined(separator: "\n")
    }
}
