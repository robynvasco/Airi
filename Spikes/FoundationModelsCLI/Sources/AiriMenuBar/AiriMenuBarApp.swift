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
    @Published var batch: CalendarReviewBatch

    init() {
        self.batch = CalendarReviewBatch(proposals: SampleCalendarProposals.items)
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
}

struct CalendarReviewPopover: View {
    @ObservedObject var viewModel: CalendarReviewViewModel

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach($viewModel.batch.proposals, id: \.id) { $proposal in
                        CalendarProposalRow(proposal: $proposal)
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
                Text("\(viewModel.selectedCount) von \(viewModel.batch.proposals.count) ausgewählt")
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
        }
        .padding(12)
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

enum SampleCalendarProposals {
    static let items: [CalendarProposal] = [
        CalendarProposal(
            id: "calendar-1",
            isSelected: true,
            sourceInstruction: "Create a work calendar event for Hochschuldidaktik online on Friday, 12 June, from 10:00 to 11:00.",
            draft: CalendarEventDraft(
                title: "Hochschuldidaktik",
                startDate: "2026-06-12",
                startTime: "10:00",
                endTime: "11:00",
                durationMinutes: 60,
                location: "online",
                participants: [],
                calendarName: "Arbeit",
                notes: ""
            ),
            reviewStatus: .ready,
            warnings: []
        ),
        CalendarProposal(
            id: "calendar-2",
            isSelected: true,
            sourceInstruction: "Create a backup Hochschuldidaktik work calendar event online on Friday, 26 June, at 10:00 because 24 June may conflict.",
            draft: CalendarEventDraft(
                title: "Hochschuldidaktik Ausweichtermin",
                startDate: "2026-06-26",
                startTime: "10:00",
                endTime: "11:00",
                durationMinutes: 60,
                location: "online",
                participants: [],
                calendarName: "Arbeit",
                notes: "Ausweichtermin, weil am 24.6. eventuell ein Konflikt besteht."
            ),
            reviewStatus: .ready,
            warnings: []
        ),
        CalendarProposal(
            id: "calendar-3",
            isSelected: true,
            sourceInstruction: "Create an optional Hochschuldidaktik work calendar event online on Wednesday, 29 July, at 11:15, marked as tentative because not everyone can attend.",
            draft: CalendarEventDraft(
                title: "Vielleicht: Hochschuldidaktik",
                startDate: "2026-07-29",
                startTime: "11:15",
                endTime: "12:15",
                durationMinutes: 60,
                location: "online",
                participants: [],
                calendarName: "Arbeit",
                notes: "Eher nicht, da nicht alle können. Vielleicht trotzdem eintragen."
            ),
            reviewStatus: .needsReview,
            warnings: [
                CalendarProposalWarning(
                    field: "notes",
                    message: "Der Termin ist optional oder unsicher."
                )
            ]
        )
    ]
}
