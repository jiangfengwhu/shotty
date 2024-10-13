import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {

            PluginManagerView(appState: appState)
                .tabItem {
                    Label("插件管理".localized, systemImage: "puzzlepiece")
                }
                .tag(0)
            ShortcutsSettingsView(appState: appState)
                .tabItem {
                    Label("快捷键".localized, systemImage: "keyboard")
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
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("截图".localized + ":")
                    .frame(width: 100, alignment: .trailing)
                KeyboardShortcuts.Recorder(
                    for: .openCaptureScreen,
                    onChange: { _ in
                        appState.statusBar?.updateMenuShortcuts()
                    }
                )
                .frame(width: 200)
            }

            HStack {
                Text("打开Shotty".localized + ":")
                    .frame(width: 100, alignment: .trailing)
                KeyboardShortcuts.Recorder(
                    for: .openContentView,
                    onChange: { _ in
                        appState.statusBar?.updateMenuShortcuts()
                    }
                )
                .frame(width: 200)
            }

            HStack {
                Text("保存目录".localized + ":")
                    .frame(width: 100, alignment: .trailing)
                    .padding(.trailing, 36)

                HStack {
                    Button(action: {
                        Shotty.Utils.selectDirectory { url in
                            appState.setSaveDirectory(directory: url)
                        }
                    }) {
                        Text(appState.saveDirectory?.path ?? "\("请选择保存目录".localized)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(width: 200)
            }

            Spacer()
        }
        .padding()
    }
}
