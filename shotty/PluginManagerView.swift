import SwiftUI

struct PluginManagerView: View {
    @State private var selectedPlugin: String?  // 用于存储用户选择的插件
    @ObservedObject var appState: AppState
    @State private var hoveredPlugin: String?  // 用于存储悬停的插件

    var body: some View {
        VStack {
            List(appState.plugins, id: \.self, selection: $selectedPlugin) {
                plugin in
                HStack {
                    Text(plugin.replacingOccurrences(of: ".html", with: ""))  // 插件名称
                    Spacer()
                    // 判断是否为默认插件
                    Text(appState.isDefaultPlugin(plugin: plugin) ? "是" : "否")  // 默认插件状态
                        .foregroundColor(
                            appState.isDefaultPlugin(plugin: plugin)
                                ? .green : .red)
                }
                .padding()
                .background(
                    hoveredPlugin == plugin && selectedPlugin != plugin
                        ? Color.gray.opacity(0.2) : Color.clear
                )  // 选中和悬停背景
                .cornerRadius(5)
                .onHover { hovering in
                    hoveredPlugin = hovering ? plugin : nil  // 更新悬停状态
                }
            }
            .frame(maxWidth: .infinity)

            Spacer()

            // 左下角按钮
            HStack {
                Button("设置为启动插件") {
                    if let selectedPlugin = selectedPlugin {
                        appState.setPreferredPlugin(plugin: selectedPlugin)
                        appState.reloadPlugins()
                    }
                }
                .padding()

                Button("上传插件") {
                    uploadPlugin()
                }
                .padding()
            }
        }
        .onAppear {
            appState.reloadPlugins()
        }
    }

    private func uploadPlugin() {
        Shotty.Utils.selectHTMLFile { url in
            appState.savePlugin(url: url)
        }
    }
}
