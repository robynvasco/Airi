import XCTest
@testable import AiriLocalCore

final class CalendarReviewBatchTests: XCTestCase {
    func testSelectionOperations() {
        var batch = CalendarReviewBatch(proposals: [
            proposal(id: "calendar-1", isSelected: true),
            proposal(id: "calendar-2", isSelected: true)
        ])

        XCTAssertEqual(batch.selectedCount, 2)

        batch.setSelected(false, for: "calendar-1")
        XCTAssertEqual(batch.selectedCount, 1)
        XCTAssertEqual(batch.selectedProposals.map(\.id), ["calendar-2"])

        batch.deselectAll()
        XCTAssertEqual(batch.selectedCount, 0)

        batch.selectAll()
        XCTAssertEqual(batch.selectedCount, 2)
    }

    func testUpdateDraft() {
        var batch = CalendarReviewBatch(proposals: [
            proposal(id: "calendar-1", isSelected: true)
        ])

        var draft = batch.proposals[0].draft
        draft.title = "Edited title"
        draft.startDate = "2026-06-12"

        batch.updateDraft(draft, for: "calendar-1")

        XCTAssertEqual(batch.proposals[0].draft.title, "Edited title")
        XCTAssertEqual(batch.proposals[0].draft.startDate, "2026-06-12")
    }

    private func proposal(id: String, isSelected: Bool) -> CalendarProposal {
        CalendarProposal(
            id: id,
            isSelected: isSelected,
            sourceInstruction: "source",
            draft: CalendarEventDraft(
                title: "Title",
                startDate: "",
                startTime: "10:00",
                endTime: "11:00",
                durationMinutes: 60,
                location: "",
                participants: [],
                calendarName: "Personal",
                notes: ""
            ),
            reviewStatus: .ready,
            warnings: []
        )
    }
}
