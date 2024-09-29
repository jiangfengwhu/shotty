import AppKit
import SwiftUI
import KeyboardShortcuts

class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    var captureAction: (() -> Void)?
    var openContentViewAction: (() -> Void)?
    var openSettingsAction: (() -> Void)?
    var openPluginManagerAction: (() -> Void)?
    
    init() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)

        // 添加菜单
        let menu = NSMenu()
        
        // 添加截图菜单项
        let captureItem = NSMenuItem(title: "截图", action: #selector(captureScreen), keyEquivalent: "2")
        captureItem.target = self
        menu.addItem(captureItem)

        // 添加打开 ContentView 的菜单项
        let openContentViewItem = NSMenuItem(title: "打开截图结果", action: #selector(openContentView), keyEquivalent: "o")
        openContentViewItem.target = self
        menu.addItem(openContentViewItem)

        // 添加设置的菜单项
        let settingsItem = NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // 添加打开插件管理视图的菜单项
        let openPluginManagerItem = NSMenuItem(title: "插件管理", action: #selector(openPluginManager), keyEquivalent: "p")
        openPluginManagerItem.target = self
        menu.addItem(openPluginManagerItem)

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

    @objc func openContentView() {
        openContentViewAction?()
    }

    @objc func openSettings() {
        openSettingsAction?() // 调用设置窗口的操作
    }

    @objc func openPluginManager() {
        openPluginManagerAction?()
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
            
            // 更新设置菜单项的快捷键
            if let settingsItem = menu.item(withTitle: "设置") {
                let shortcut = KeyboardShortcuts.getShortcut(for: .openSettings)
                settingsItem.setShortcut(shortcut)
            }
        }
    }
}
