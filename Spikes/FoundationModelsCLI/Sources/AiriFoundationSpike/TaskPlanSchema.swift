import Foundation
import FoundationModels

@available(macOS 26.0, *)
enum TaskPlanSchema {
    static var schema: GenerationSchema {
        get throws {
            let task = DynamicGenerationSchema(
                name: "PlannedTask",
                description: "One independent task extracted from the user's request.",
                properties: [
                    .init(name: "text", description: "The exact user-facing text for this task only.", schema: .init(type: String.self)),
                    .init(name: "type", description: "Task type, such as calendarEvent, reminder, note, file, or unknown.", schema: .init(type: String.self)),
                    .init(name: "suggestedTools", description: "Tool names that may be useful for this task.", schema: .init(arrayOf: .init(type: String.self), minimumElements: 0, maximumElements: 4)),
                    .init(name: "reason", description: "Short reason why this is a separate task.", schema: .init(type: String.self))
                ]
            )

            let plan = DynamicGenerationSchema(
                name: "TaskPlan",
                description: "A list of independent tasks extracted from the user's request.",
                properties: [
                    .init(name: "tasks", description: "Independent tasks in the same order as the user request.", schema: .init(arrayOf: .init(referenceTo: "PlannedTask"), minimumElements: 1, maximumElements: 8))
                ]
            )

            return try GenerationSchema(root: plan, dependencies: [task])
        }
    }
}

@available(macOS 26.0, *)
enum TaskPlanParser {
    static func inputTasks(from content: GeneratedContent) -> [InputTask] {
        let tasks = (try? content.value([GeneratedContent].self, forProperty: "tasks")) ?? []

        return tasks.enumerated().compactMap { offset, taskContent in
            guard let text = try? taskContent.value(String.self, forProperty: "text") else {
                return nil
            }

            let type = (try? taskContent.value(String.self, forProperty: "type")) ?? "unknown"
            let suggestedTools = (try? taskContent.value([String].self, forProperty: "suggestedTools")) ?? []
            let reason = (try? taskContent.value(String.self, forProperty: "reason")) ?? ""

            return InputTask(
                index: offset + 1,
                text: text,
                source: .model,
                type: type,
                suggestedTools: suggestedTools,
                reason: reason
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

