import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let openCaptureScreen = Self("openCaptureScreen", default: .init(.k, modifiers: [.command, .option]))
    static let openContentView = Self("openContentView", default: .init(.o, modifiers: [.command])) // 添加打开 ContentView 的快捷键
}
