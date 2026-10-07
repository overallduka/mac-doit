import AppKit
import SwiftUI

/// Menu bar item (Shia's face + pending count) that toggles a popover with the list.
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)  // no Dock icon
        app.run()
    }

    let store = Store()
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = NSHostingController(rootView: ContentView(store: store))
        host.sizingOptions = .preferredContentSize  // popover follows the SwiftUI frame (resizable)
        popover.contentViewController = host
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: .aqua)  // the glass design is light

        let button = statusItem.button!
        button.image = Self.icon
        button.imagePosition = .imageLeading
        button.target = self
        button.action = #selector(toggle)
        store.onChange = { [weak self] in self?.updateCount() }
        updateCount()

        // No menu bar (LSUIElement) means ⌘V/⌘C/⌘X/⌘A/⌘Z have nowhere to route. An invisible Edit menu fixes that.
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem()
        editItem.submenu = edit
        NSApp.mainMenu = NSMenu()
        NSApp.mainMenu?.addItem(editItem)
    }

    private var shownCount = -1

    /// Runs on every store change (each notes keystroke too): only touch the menu bar when the number moves.
    func updateCount() {
        let n = store.pending
        guard n != shownCount else { return }
        shownCount = n
        statusItem.button?.attributedTitle = NSAttributedString(
            string: n > 0 ? " \(n)" : "",
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold)])
    }

    @objc func toggle() {
        if popover.isShown { popover.performClose(nil); return }
        store.now = Date()
        NSApp.activate()
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    /// Colored (non-template) round face for the menu bar.
    static let icon = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
        NSBezierPath(ovalIn: rect).addClip()
        shiaFace.draw(in: rect)
        return true
    }
}
