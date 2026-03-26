import AppKit
import SwiftUI

class ChecklistWindowController {
    private var window: NSWindow?
    private let checklistManager: ChecklistManager
    var onChecklistChanged: (() -> Void)?

    init(checklistManager: ChecklistManager) {
        self.checklistManager = checklistManager
    }

    func show() {
        guard window == nil else {
            window?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let view = ChecklistWindowView(
            checklistManager: checklistManager,
            onToggle: { [weak self] in
                self?.onChecklistChanged?()
            }
        )

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Bedtime Checklist"
        win.level = .floating
        win.contentView = NSHostingView(rootView: view)
        win.isReleasedWhenClosed = false
        win.center()
        win.makeKeyAndOrderFront(nil)

        NSApplication.shared.activate(ignoringOtherApps: true)
        self.window = win
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
    }
}

struct ChecklistWindowView: View {
    @ObservedObject var checklistManager: ChecklistManager
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bedtime Routine")
                .font(.headline)
                .padding(.bottom, 4)

            ForEach(0..<checklistManager.items.count, id: \.self) { index in
                HStack(spacing: 10) {
                    Image(systemName: checklistManager.items[index].completed ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(checklistManager.items[index].completed ? .green : .secondary)
                        .font(.title3)

                    Text(checklistManager.items[index].title)
                        .strikethrough(checklistManager.items[index].completed)
                        .foregroundColor(checklistManager.items[index].completed ? .secondary : .primary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    checklistManager.toggle(at: index)
                    onToggle()
                }
            }

            Spacer()

            if checklistManager.items.allSatisfy({ $0.completed }) {
                Text("All done! Time for bed.")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .frame(minWidth: 280, minHeight: 200)
    }
}
