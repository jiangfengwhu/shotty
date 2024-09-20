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
    @ObservedObject private var contentViewModel = ContentViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController()
        statusBar?.captureAction = captureScreen
        
        // 添加全局快捷键监听
        KeyboardShortcuts.onKeyUp(for: .openCaptureScreeen) {
            self.captureScreen()
        }
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

// 实现NSWindowDelegate协议
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // 隐藏窗口而不是销毁
        contentWindow?.orderOut(nil)
    }
    
    // 修改关闭按钮的操作为隐藏窗口
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        contentWindow?.orderOut(nil) // 隐藏窗口
        return false // 返回false以防止窗口被销毁
    }
    
    // 确保应用程序在最后一个窗口关闭后不退出
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
