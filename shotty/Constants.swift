import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let openCaptureScreen = Self("openCaptureScreen", default: .init(.k, modifiers: [.command, .option]))
    static let openSettings = Self("openSettings", default: .init(KeyboardShortcuts.Key.comma, modifiers: [.command]))
    static let openContentView = Self("openContentView", default: .init(.o, modifiers: [.command])) // 添加打开 ContentView 的快捷键
}
