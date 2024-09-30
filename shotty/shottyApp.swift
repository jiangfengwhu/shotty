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
            SettingsView(appState: appDelegate.appState)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}


class AppDelegate: NSObject, NSApplicationDelegate {
    @ObservedObject var appState: AppState

    override init() {
        self.appState = AppState()
        super.init()
        self.appState.setDelegate(delegate: self)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState.initStatusBar()
        // 添加全局快捷键监听
        KeyboardShortcuts.onKeyUp(for: .openCaptureScreen) {
            self.appState.captureScreen()
        }
        // 添加打开 ContentView 的快捷键监听
        KeyboardShortcuts.onKeyUp(for: .openContentView) {
            self.appState.showContentWindow() // 调用打开 ContentView 的方法
        }
    }

}

// 实现 NSWindowDelegate 协议
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
       if let contentWindow = appState.contentWindow,  sender === contentWindow {
           appState.closeContentWindow()
           return false // 返回 false 以防止窗口被销毁
       }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
