import Foundation

actor ToolCallRecorder {
    private var calls: [String] = []

    func record(_ call: String) {
        calls.append(call)
    }

    func snapshot() -> [String] {
        calls
    }
}

