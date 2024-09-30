import SwiftUI
import AppKit

class AppState: ObservableObject {
    @Published var isWindowOpen: Bool = false {
        didSet {
            updateDockIconVisibility()
        }
    }
    @Published var capturedImage: NSImage?
    var contentWindow: NSWindow?
    var statusBar: StatusBarController?
    var delegate: AppDelegate?
    
    func setDelegate(delegate: AppDelegate) {
        self.delegate = delegate
    }
    
    private func updateDockIconVisibility() {
        if isWindowOpen {
            NSApp.setActivationPolicy(.regular) // 显示 Dock 图标
        } else {
            NSApp.setActivationPolicy(.accessory) // 隐藏 Dock 图标
        }
    }
    
    @MainActor func initStatusBar() {
        statusBar = StatusBarController()
        statusBar?.captureAction = captureScreen
        statusBar?.openContentViewAction = showContentWindow
        statusBar?.openSettingsAction = openSettings // 添加设置窗口的操作
        statusBar?.updateMenuShortcuts()
    }
    
    func openSettings() {
        showSettingsWindow()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func captureScreen() {
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-ic"]  // -i 交互式, -c 复制到剪贴板
        
        task.launch()
        task.waitUntilExit()
        
        // 从剪贴板读取图像
        if let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            print("成功从剪贴板读取截图")
            capturedImage = image
            showContentWindow()
        } else {
            print("无法从剪贴板读取截图")
        }
    }
    
    func showContentWindow() {
        if contentWindow == nil {
            let contentView = ContentView(appState: self)
            contentWindow = NSWindow(
                contentRect: NSRect(x: 100, y: 100, width: 600, height: 400),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            contentWindow?.title = "截图结果"
            contentWindow?.contentView = NSHostingView(rootView: contentView)
            contentWindow?.delegate = delegate
        }
        NSApp.activate(ignoringOtherApps: true)
        contentWindow?.makeKeyAndOrderFront(nil)
        isWindowOpen = true // 更新窗口状态
    }
    
    func closeContentWindow() {
        contentWindow?.orderOut(nil)
        isWindowOpen = false // 更新窗口状态
    }
}
