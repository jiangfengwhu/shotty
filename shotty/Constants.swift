import KeyboardShortcuts
import Foundation

extension KeyboardShortcuts.Name {
    static let openCaptureScreen = Self("openCaptureScreen", default: .init(.k, modifiers: [.command, .option]))
    static let openContentView = Self("openContentView", default: .init(.o, modifiers: [.command])) // 添加打开 ContentView 的快捷键
}

enum Constants {    
    static let defaultPluginName = "shotty.html"
    static let pluginDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("plugins")
}
