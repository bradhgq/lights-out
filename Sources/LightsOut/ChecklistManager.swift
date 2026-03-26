import Foundation

struct ChecklistItem {
    let title: String
    var completed: Bool
}

class ChecklistManager: ObservableObject {
    @Published private(set) var items: [ChecklistItem]

    init(items: [String]) {
        self.items = items.map { ChecklistItem(title: $0, completed: false) }
    }

    func toggle(at index: Int) {
        guard index >= 0 && index < items.count else { return }
        items[index].completed.toggle()
    }

    func reset(items: [String]) {
        self.items = items.map { ChecklistItem(title: $0, completed: false) }
    }
}
