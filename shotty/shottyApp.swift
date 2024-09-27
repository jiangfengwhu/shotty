//
//  shottyApp.swift
//  shotty
//
//  Created by Feng Jiang on 2024/9/18.
//

import SwiftUI
import KeyboardShortcuts // 添加导入

@main
struct ShottyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBar: StatusBarController?
    var contentWindow: NSWindow?
    var settingsWindow: NSWindow? // 添加设置窗口的引用
    @ObservedObject private var contentViewModel = ContentViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController()
        statusBar?.captureAction = captureScreen
        statusBar?.openContentViewAction = showContentWindow
        statusBar?.openSettingsAction = openSettings // 添加设置窗口的操作

        // 添加全局快捷键监听
        KeyboardShortcuts.onKeyUp(for: .openCaptureScreen) {
            self.captureScreen()
        }

        // 添加打开设置窗口的快捷键监听
        KeyboardShortcuts.onKeyUp(for: .openSettings) {
            self.openSettings()
        }

        // 添加打开 ContentView 的快捷键监听
        KeyboardShortcuts.onKeyUp(for: .openContentView) {
            self.showContentWindow() // 调用打开 ContentView 的方法
        }
        statusBar?.updateMenuShortcuts()
    }

    func openSettings() {
        if settingsWindow == nil {
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 100, y: 100, width: 400, height: 300),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "设置"
            settingsWindow?.contentView = NSHostingView(rootView: SettingsView(statusBarController: statusBar!)) // 传递 StatusBarController 实例
            settingsWindow?.delegate = self // 设置窗口代理
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
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
            contentViewModel.capturedImage = image
            showContentWindow()
        } else {
            print("无法从剪贴板读取截图")
        }
    }
    
    func showContentWindow() {
        if contentWindow == nil {
            let contentView = ContentView(viewModel: contentViewModel)
            contentWindow = NSWindow(
                contentRect: NSRect(x: 100, y: 100, width: 300, height: 300),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            contentWindow?.title = "截图结果"
            contentWindow?.contentView = NSHostingView(rootView: contentView)
            contentWindow?.delegate = self
        }
        contentWindow?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

// 实现 NSWindowDelegate 协议
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let closedWindow = notification.object as? NSWindow {
            if closedWindow === settingsWindow {
                settingsWindow = nil // 关闭时将设置窗口引用设置为 nil
            } else {
                contentWindow?.orderOut(nil)
            }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === settingsWindow {
            settingsWindow?.orderOut(nil) // 隐藏设置窗口
            return false // 返回 false 以防止窗口被销毁
        }
        contentWindow?.orderOut(nil) // 隐藏内容窗口
        return false // 返回 false 以防止窗口被销毁
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
