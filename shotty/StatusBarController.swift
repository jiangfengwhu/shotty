import AppKit

class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    var captureAction: (() -> Void)?

    init() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)

        // 添加菜单
        let menu = NSMenu()
        let captureItem = NSMenuItem(title: "截图", action: #selector(captureScreen), keyEquivalent: "2")
        captureItem.keyEquivalentModifierMask = [.command, .shift] // 设置快捷键为 Command + Shift + 6
        captureItem.target = self // 设置目标为当前对象
        menu.addItem(captureItem)
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.shared.terminate), keyEquivalent: "q"))
        statusItem.menu = menu

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
