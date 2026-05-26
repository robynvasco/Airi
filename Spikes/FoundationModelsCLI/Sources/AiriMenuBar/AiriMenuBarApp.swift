import AiriLocalCore
import SwiftUI

@main
struct AiriMenuBarApp: App {
    @StateObject private var viewModel = CalendarReviewViewModel()

    var body: some Scene {
        MenuBarExtra("Airi", systemImage: "sparkles") {
            CalendarReviewPopover(viewModel: viewModel)
                .frame(width: 460, height: 620)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class CalendarReviewViewModel: ObservableObject {
    @Published var input: String
    @Published var batch: CalendarReviewBatch
    @Published var isPlanning = false
    @Published var statusMessage = "Bereit"
    @Published var lastResult: LocalPlanningResult?

    init() {
        self.input = ""
        self.batch = CalendarReviewBatch(proposals: [])
    }

    var selectedCount: Int {
        batch.selectedCount
    }

    func selectAll() {
        batch.selectAll()
    }

    func deselectAll() {
        batch.deselectAll()
    }

    func update(_ proposal: CalendarProposal) {
        guard let index = batch.proposals.firstIndex(where: { $0.id == proposal.id }) else {
            return
        }
        batch.proposals[index] = proposal
    }

    func plan() {
        let request = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty, !isPlanning else {
            return
        }

        isPlanning = true
        statusMessage = "Plane..."

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                LocalPlanningPipeline().run(input: request)
            }.value

            self.lastResult = result
            self.batch = result.reviewBatch
            self.isPlanning = false

            if result.reviewBatch.proposals.isEmpty {
                self.statusMessage = "Keine Kalendervorschläge"
            } else {
                self.statusMessage = "\(result.reviewBatch.proposals.count) Vorschläge"
            }
        }
    }
}

struct CalendarReviewPopover: View {
    @ObservedObject var viewModel: CalendarReviewViewModel

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            inputArea

            Divider()

            ScrollView {
                LazyVStack(spacing: 10) {
                    if viewModel.batch.proposals.isEmpty {
                        emptyState
                    } else {
                        ForEach($viewModel.batch.proposals, id: \.id) { $proposal in
                            CalendarProposalRow(proposal: $proposal)
                        }
                    }
                }
                .padding(12)
            }

            Divider()

            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 28, height: 28)

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

            Button("Keine") {
                viewModel.deselectAll()
            }
            .disabled(viewModel.batch.proposals.isEmpty)
        }
        .padding(12)
    }

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        .padding(12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Noch keine Vorschläge")
                .font(.headline)
            Text("Gib oben einen Auftrag ein.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Schließen") {
                NSApplication.shared.keyWindow?.close()
            }

            Spacer()

            Button {
                // EventKit writing will be connected after the review UI is stable.
            } label: {
                Label("Ausgewählte eintragen", systemImage: "calendar.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedCount == 0)
        }
        .padding(12)
    }

    private var selectionText: String {
        if viewModel.batch.proposals.isEmpty {
            return "Keine Vorschläge"
        }
        return "\(viewModel.selectedCount) von \(viewModel.batch.proposals.count) ausgewählt"
    }
}

struct CalendarProposalRow: View {
    @Binding var proposal: CalendarProposal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Toggle("", isOn: $proposal.isSelected)
                    .labelsHidden()

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Titel", text: $proposal.draft.title)
                        .font(.headline)

                    HStack(spacing: 8) {
                        TextField("Datum", text: $proposal.draft.startDate)
                        TextField("Start", text: $proposal.draft.startTime)
                        TextField("Ende", text: $proposal.draft.endTime)
                    }

                    HStack(spacing: 8) {
                        TextField("Ort", text: $proposal.draft.location)
                        TextField("Kalender", text: $proposal.draft.calendarName)
                    }

                    TextField("Teilnehmer", text: participantsBinding)

                    TextField("Notizen", text: $proposal.draft.notes, axis: .vertical)
                        .lineLimit(2...4)

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
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
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
}
