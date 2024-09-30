import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ShortcutsSettingsView(statusBarController: appState.statusBar)
                .tabItem {
                    Label("快捷键", systemImage: "keyboard")
                }
                .tag(0)
            
            PluginManagerView()
                .tabItem {
                    Label("插件管理", systemImage: "puzzlepiece")
                }
                .tag(1)
        }
        .frame(width: 500, height: 300)
        .padding()
    }
}

struct TabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 12))
            }
            .foregroundColor(isSelected ? .blue : .primary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ShortcutsSettingsView: View {
    var statusBarController: StatusBarController?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("打开截图:")
                KeyboardShortcuts.Recorder(for: .openCaptureScreen, onChange: { _ in
                    statusBarController?.updateMenuShortcuts()
                })
                .frame(width: 200)
            }
            
            HStack {
                Text("打开内容视图:")
                KeyboardShortcuts.Recorder(for: .openContentView, onChange: { _ in
                    statusBarController?.updateMenuShortcuts()
                })
                .frame(width: 200)
            }
            
            Spacer()
        }
        .padding()
    }
}

// xcode 预览
//#Preview {
//    SettingsView(statusBarController: StatusBarController())
//}
