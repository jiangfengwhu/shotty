import AppKit
import KeyboardShortcuts
import SwiftUI

class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    var captureAction: (() -> Void)?
    var openContentViewAction: (() -> Void)?
    var openSettingsAction: (() -> Void)?

    init() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)

        // 添加菜单
        let menu = NSMenu()

        // 添加截图菜单项
        let captureItem = NSMenuItem(
            title: "截图", action: #selector(captureScreen), keyEquivalent: "2")
        captureItem.target = self
        menu.addItem(captureItem)

        // 添加打开 ContentView 的菜单项
        let openContentViewItem = NSMenuItem(
            title: "打开面板", action: #selector(openContentView), keyEquivalent: "o")
        openContentViewItem.target = self
        menu.addItem(openContentViewItem)

        menu.addItem(NSMenuItem.separator())

        // 添加设置的菜单项

        let settingsItem = NSMenuItem(
            title: "设置", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(
            NSMenuItem(
                title: "退出", action: #selector(NSApplication.shared.terminate), keyEquivalent: "q"))
        statusItem.menu = menu

        if let statusBarButton = statusItem.button {
            if let appIcon = NSApp.applicationIconImage {
                let resizedIcon = resizeImage(image: appIcon, w: 22, h: 22)
                statusBarButton.image = resizedIcon
            }
            statusBarButton.action = #selector(captureScreen)
            statusBarButton.target = self
        }
    }

    @objc func captureScreen() {
        captureAction?()
    }

    @objc func openContentView() {
        openContentViewAction?()
    }

    @objc func openSettings() {
        openSettingsAction?()  // 调用设置窗口的操作
    }

    @MainActor func updateMenuShortcuts() {
        if let menu = statusItem.menu {
            // 更新截图菜单项的快捷键
            if let captureItem = menu.item(withTitle: "截图") {
                let shortcut = KeyboardShortcuts.getShortcut(for: .openCaptureScreen)
                captureItem.setShortcut(shortcut)
            }

            // 更新打开内容视图菜单项的快捷键
            if let openContentViewItem = menu.item(withTitle: "打开截图结果") {
                let shortcut = KeyboardShortcuts.getShortcut(for: .openContentView)
                openContentViewItem.setShortcut(shortcut)
            }
        }
    }

    private func resizeImage(image: NSImage, w: Int, h: Int) -> NSImage {
        let destSize = NSMakeSize(CGFloat(w), CGFloat(h))
        let newImage = NSImage(size: destSize)
        newImage.lockFocus()
        image.draw(
            in: NSRect(x: 0, y: 0, width: destSize.width, height: destSize.height),
            from: NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height),
            operation: .copy,
            fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}
