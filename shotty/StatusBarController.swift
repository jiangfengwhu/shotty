import AppKit

class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    var captureAction: (() -> Void)?

    init() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)

        if let statusBarButton = statusItem.button {
            statusBarButton.image = NSImage(systemSymbolName: "camera", accessibilityDescription: "截图")
            statusBarButton.action = #selector(captureScreen)
            statusBarButton.target = self
        }
    }

    @objc func captureScreen() {
        captureAction?()
    }
}
