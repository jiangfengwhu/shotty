import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var statusBarController: StatusBarController // 添加 StatusBarController 的引用

    var body: some View {
        VStack {
            Text("设置快捷键")
                .font(.largeTitle)
                .padding()

            HStack {
                Text("打开截图:")
                KeyboardShortcuts.Recorder(for: .openCaptureScreen, onChange: { (shortcut: KeyboardShortcuts.Shortcut?) in
                    statusBarController.updateMenuShortcuts()
                })
                    .frame(width: 200)
            }
            .padding()

            HStack {
                Text("打开内容视图:")
                KeyboardShortcuts.Recorder(for: .openContentView,onChange: { (shortcut: KeyboardShortcuts.Shortcut?) in
                    statusBarController.updateMenuShortcuts()
                })
                    .frame(width: 200)
            }
            .padding()

            Spacer()
        }
        .padding()
    }
}
