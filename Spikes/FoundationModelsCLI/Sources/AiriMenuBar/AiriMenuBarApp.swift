import AiriLocalCore
import EventKit
import SwiftUI

@main
struct AiriMenuBarApp: App {
    @StateObject private var viewModel = ActionReviewViewModel()

    var body: some Scene {
        MenuBarExtra("Airi", systemImage: "sparkles") {
            ActionReviewPopover(viewModel: viewModel)
                .frame(width: 520, height: 680)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class ActionReviewViewModel: ObservableObject {
    @Published var input = ""
    @Published var batch = CalendarReviewBatch(proposals: [])
    @Published var isPlanning = false
    @Published var statusMessage = "Bereit"
    @Published var progressIndex = 0
    @Published var availableCalendarNames: [String] = []
    @Published var calendarStatus = "Kalender werden geladen..."
    @Published var lastResult: LocalPlanningResult?

    private let calendarProvider = MacCalendarProvider()

    init() {
        Task {
            await loadCalendars()
        }
    }

    var selectedCount: Int {
        batch.selectedCount
    }

    var progressSteps: [String] {
        [
            "Eingabe lesen",
            "Aufgaben erkennen",
            "Kontext und Kalender einbeziehen",
            "Felder vorbereiten",
            "Vorschläge bauen"
        ]
    }

    func loadCalendars() async {
        do {
            let names = try await calendarProvider.writableCalendarNames()
            availableCalendarNames = names
            calendarStatus = names.isEmpty
                ? "Keine beschreibbaren Kalender gefunden"
                : "\(names.count) Kalender verfügbar"
        } catch {
            availableCalendarNames = []
            calendarStatus = "Kalender nicht verfügbar"
        }
    }

    func selectAll() {
        batch.selectAll()
    }

    func deselectAll() {
        batch.deselectAll()
    }

    func plan() {
        let request = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty, !isPlanning else {
            return
        }

        isPlanning = true
        progressIndex = 0
        statusMessage = "Eingabe wird gelesen..."

        let progressTask = Task {
            await runProgressLoop()
        }

        Task {
            let calendars = availableCalendarNames
            let result = await Task.detached(priority: .userInitiated) {
                LocalPlanningPipeline().run(
                    input: request,
                    availableCalendarNames: calendars
                )
            }.value

            progressTask.cancel()
            lastResult = result
            batch = result.reviewBatch
            isPlanning = false
            progressIndex = progressSteps.count

            let taskCount = result.tasks.count
            let proposalCount = result.reviewBatch.proposals.count
            statusMessage = "\(taskCount) Aufgaben erkannt, \(proposalCount) Vorschläge vorbereitet"
        }
    }

    private func runProgressLoop() async {
        while !Task.isCancelled {
            let boundedIndex = min(progressIndex, progressSteps.count - 1)
            statusMessage = progressSteps[boundedIndex]

            try? await Task.sleep(for: .milliseconds(1100))
            if Task.isCancelled {
                return
            }

            progressIndex = min(progressIndex + 1, progressSteps.count - 1)
        }
    }
}

struct ActionReviewPopover: View {
    @ObservedObject var viewModel: ActionReviewViewModel

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            inputArea

            Divider()

            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.batch.proposals.isEmpty {
                        emptyState
                    } else {
                        ForEach($viewModel.batch.proposals, id: \.id) { $proposal in
                            CalendarProposalRow(
                                proposal: $proposal,
                                calendarNames: viewModel.availableCalendarNames
                            )
                        }
                    }
                }
                .padding(12)
            }

            Divider()

            footer
        }
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Airi")
                    .font(.headline)
                Text(selectionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Alle") {
                viewModel.selectAll()
            }
            .disabled(viewModel.batch.proposals.isEmpty)

            Button("Keine") {
                viewModel.deselectAll()
            }
            .disabled(viewModel.batch.proposals.isEmpty)
        }
        .padding(12)
    }

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Was soll Airi vorbereiten?", text: $viewModel.input, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.isPlanning)
                .onSubmit {
                    viewModel.plan()
                }

            HStack(spacing: 10) {
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                if viewModel.isPlanning {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    viewModel.plan()
                } label: {
                    Label("Planen", systemImage: "wand.and.stars")
                }
                .disabled(viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isPlanning)
            }

            if viewModel.isPlanning {
                ProgressTimeline(
                    steps: viewModel.progressSteps,
                    currentIndex: viewModel.progressIndex
                )
            }

            Text(viewModel.calendarStatus)
                .font(.caption)
                .foregroundStyle(.secondary)

            diagnosticMessages

            PromptTraceView(result: viewModel.lastResult)
        }
        .padding(12)
        .background(.thinMaterial)
    }

    private var diagnosticMessages: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let planningError = viewModel.lastResult?.planningError {
                Label(planningError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }

            if let result = viewModel.lastResult, !result.extractionErrors.isEmpty {
                ForEach(result.extractionErrors, id: \.self) { error in
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Noch keine Vorschläge")
                .font(.headline)
            Text("Airi zeigt hier vorbereitete Aktionen, bevor etwas ausgeführt wird.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Schließen") {
                NSApplication.shared.keyWindow?.close()
            }

            Spacer()

            Button {
                // Action execution will be connected after the review UI is stable.
            } label: {
                Label("Ausgewählte ausführen", systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedCount == 0)
        }
        .padding(12)
        .background(.thinMaterial)
    }

    private var selectionText: String {
        if viewModel.batch.proposals.isEmpty {
            return "Keine Vorschläge"
        }
        return "\(viewModel.selectedCount) von \(viewModel.batch.proposals.count) ausgewählt"
    }
}

struct ProgressTimeline: View {
    let steps: [String]
    let currentIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 7) {
                    Image(systemName: symbol(for: index))
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 14)
                    Text(step)
                        .font(.caption)
                        .foregroundStyle(index <= currentIndex ? .primary : .secondary)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func symbol(for index: Int) -> String {
        if index < currentIndex {
            return "checkmark.circle.fill"
        }
        if index == currentIndex {
            return "circle.circle.fill"
        }
        return "circle"
    }
}

struct PromptTraceView: View {
    let result: LocalPlanningResult?

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                if let result {
                    PromptBlock(
                        title: "Step 3 - Task Prompt",
                        prompt: result.planPrompt,
                        response: result.planResponse,
                        error: result.planningError
                    )

                    ForEach(Array(result.calendarPromptExchanges.enumerated()), id: \.offset) { _, exchange in
                        PromptBlock(
                            title: exchange.title,
                            prompt: exchange.prompt,
                            response: exchange.response,
                            error: exchange.error
                        )
                    }
                } else {
                    Text("Nach dem ersten Lauf erscheinen hier die Prompts und Modellantworten.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 6)
        } label: {
            Label("Prompts und Modellantworten", systemImage: "text.magnifyingglass")
                .font(.caption)
        }
    }
}

struct PromptBlock: View {
    let title: String
    let prompt: String
    let response: String
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)

            Text("Prompt")
                .font(.caption2)
                .foregroundStyle(.secondary)
            codeBox(prompt)

            if let error {
                Text("Fehler")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                codeBox(error)
            } else {
                Text("Antwort")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                codeBox(response.isEmpty ? "Keine Antwort gespeichert." : response)
            }
        }
    }

    private func codeBox(_ text: String) -> some View {
        ScrollView(.horizontal) {
            Text(text)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(7)
        }
        .frame(maxHeight: 130)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct CalendarProposalRow: View {
    @Binding var proposal: CalendarProposal
    let calendarNames: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Toggle("", isOn: $proposal.isSelected)
                    .labelsHidden()

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("Titel", text: $proposal.draft.title)
                            .font(.headline)
                        Spacer()
                        Text(proposal.reviewStatus == .ready ? "Bereit" : "Hinweise")
                            .font(.caption)
                            .foregroundStyle(statusColor)
                    }

                    LabeledContent("Datum") {
                        DatePicker("", selection: dateBinding, displayedComponents: .date)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    HStack(spacing: 12) {
                        LabeledContent("Start") {
                            DatePicker("", selection: startTimeBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }

                        LabeledContent("Ende") {
                            DatePicker("", selection: endTimeBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }

                    LabeledContent("Kalender") {
                        Picker("", selection: $proposal.draft.calendarName) {
                            if proposal.draft.calendarName.isEmpty {
                                Text("Nicht gewählt").tag("")
                            }
                            ForEach(calendarNames, id: \.self) { name in
                                Text(name).tag(name)
                            }
                            if !proposal.draft.calendarName.isEmpty && !calendarNames.contains(proposal.draft.calendarName) {
                                Text(proposal.draft.calendarName).tag(proposal.draft.calendarName)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 220)
                    }

                    LabeledContent("Ort") {
                        TextField("Optional", text: $proposal.draft.location)
                    }

                    LabeledContent("Personen") {
                        TextField("Optional, mit Komma trennen", text: participantsBinding)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notizen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Optional", text: $proposal.draft.notes, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    if !proposal.warnings.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(proposal.warnings, id: \.message) { warning in
                                Label(warning.message, systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var participantsBinding: Binding<String> {
        Binding(
            get: { proposal.draft.participants.joined(separator: ", ") },
            set: { value in
                proposal.draft.participants = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { DateFieldFormatters.date.date(from: proposal.draft.startDate) ?? Date() },
            set: { proposal.draft.startDate = DateFieldFormatters.date.string(from: $0) }
        )
    }

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: { DateFieldFormatters.time.date(from: proposal.draft.startTime) ?? Date() },
            set: { proposal.draft.startTime = DateFieldFormatters.time.string(from: $0) }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: { DateFieldFormatters.time.date(from: proposal.draft.endTime) ?? Date() },
            set: { proposal.draft.endTime = DateFieldFormatters.time.string(from: $0) }
        )
    }
}

enum DateFieldFormatters {
    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

@MainActor
final class MacCalendarProvider {
    private let store = EKEventStore()

    func writableCalendarNames() async throws -> [String] {
        try await requestCalendarAccessIfNeeded()

        return store.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .map(\.title)
            .removingDuplicates()
    }

    private func requestCalendarAccessIfNeeded() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .fullAccess, .writeOnly, .authorized:
            return
        case .notDetermined:
            if #available(macOS 14.0, *) {
                _ = try await store.requestFullAccessToEvents()
            } else {
                _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    store.requestAccess(to: .event) { granted, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else if granted {
                            continuation.resume()
                        } else {
                            continuation.resume(throwing: CalendarAccessError.denied)
                        }
                    }
                }
            }
        case .denied, .restricted:
            throw CalendarAccessError.denied
        @unknown default:
            throw CalendarAccessError.denied
        }
    }
}

private extension CalendarProposalRow {
    var statusColor: Color {
        proposal.reviewStatus == .ready ? .secondary : .orange
    }
}

enum CalendarAccessError: Error {
    case denied
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
