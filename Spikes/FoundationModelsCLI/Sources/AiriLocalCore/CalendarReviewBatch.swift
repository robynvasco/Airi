import Foundation

public struct CalendarReviewBatch {
    public var proposals: [CalendarProposal]

    public init(proposals: [CalendarProposal]) {
        self.proposals = proposals
    }

    public var selectedCount: Int {
        proposals.filter(\.isSelected).count
    }

    public var selectedProposals: [CalendarProposal] {
        proposals.filter(\.isSelected)
    }

    public mutating func selectAll() {
        for index in proposals.indices {
            proposals[index].isSelected = true
        }
    }

    public mutating func deselectAll() {
        for index in proposals.indices {
            proposals[index].isSelected = false
        }
    }

    public mutating func setSelected(_ isSelected: Bool, for id: String) {
        guard let index = proposals.firstIndex(where: { $0.id == id }) else {
            return
        }

        proposals[index].isSelected = isSelected
    }

    public mutating func updateDraft(_ draft: CalendarEventDraft, for id: String) {
        guard let index = proposals.firstIndex(where: { $0.id == id }) else {
            return
        }

        proposals[index].draft = draft
    }
}
