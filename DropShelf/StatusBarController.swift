import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController()
    }
}

final class StatusBarController: NSObject {
    let statusItem: NSStatusItem
    let popover: NSPopover
    let model = ShelfModel()

    override init() {
        popover = NSPopover()
        // Keep applicationDefined so user must click the status item again to close
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.contentSize = NSSize(width: 460, height: 320)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        let content = ShelfView().environmentObject(model)
        popover.contentViewController = NativePopoverController(rootView: content)

        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "paperclip.circle.fill", accessibilityDescription: "DropShelf") {
                let cfg = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
                if let configured = img.withSymbolConfiguration(cfg) {
                    button.image = configured
                } else {
                    button.image = img
                }
            } else {
                button.image = NSImage(systemSymbolName: "tray.and.arrow.down", accessibilityDescription: "DropShelf")
            }
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.wantsLayer = true

            // Add a transparent DropView on top of the button to accept drops directly on the menu bar icon
            let dropView = DropView(frame: button.bounds) { [weak self] urls in
                guard let self = self else { return }
                self.model.add(urls: urls)
                self.model.triggerSuccess()
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                self.animateButtonSuccess()
            }
            dropView.translatesAutoresizingMaskIntoConstraints = true
            dropView.autoresizingMask = [.width, .height]
            button.addSubview(dropView)
        }
    }

    @objc func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Show the existing popover content. `model` is a reference type so
            // the environment object will already be in sync; avoid recreating
            // the content controller on every toggle to reduce churn.
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func animateButtonSuccess() {
        guard let button = statusItem.button, let layer = button.layer else { return }
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
        animation.values = [0, -6, 0, -3, 0]
        animation.duration = 0.36
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(animation, forKey: "bounce")
    }
}

// MARK: - DropView (accepts file drops)

final class DropView: NSView {
    private var onDrop: ([URL]) -> Void
    
    init(frame: NSRect, onDrop: @escaping ([URL]) -> Void) {
        self.onDrop = onDrop
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let items = pb.readObjects(forClasses: [NSURL.self], options: options) as? [URL] {
            // Defer UI updates slightly to avoid layout recursion during an active drag operation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                self?.onDrop(items)
            }
            return true
        }
        return false
    }
}

// Native popover controller removed; using NSMenu with NSMenuItem.view instead for true native UI
// Native popover controller using NSVisualEffectView + NSHostingView for exact native vibrancy
final class NativePopoverController<Content: View>: NSViewController {
    private var hosting: NSHostingView<Content>!

    init(rootView: Content) {
        super.init(nibName: nil, bundle: nil)
        let effect = NSVisualEffectView()
        effect.material = .menu
        effect.state = .active
        effect.blendingMode = .withinWindow
        effect.appearance = NSApp.effectiveAppearance
        effect.wantsLayer = true

        hosting = NSHostingView(rootView: rootView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(hosting)

        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 12),
            hosting.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -12),
            hosting.topAnchor.constraint(equalTo: effect.topAnchor, constant: 10),
            hosting.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -10)
        ])

        self.view = effect
        self.view.layer?.cornerRadius = 10
        self.view.layer?.masksToBounds = true
        self.preferredContentSize = NSSize(width: 460, height: 320)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateRootView(_ rootView: Content) {
        hosting.rootView = rootView
    }
}
