import SwiftUI

struct PluginManagerView: View {
    @State private var plugins: [String] = []
    @State private var selectedPlugin: String? // 用于存储用户选择的插件
    
    var body: some View {
        VStack {
            Text("插件管理")
                .font(.largeTitle)
                .padding()
            
            List(plugins, id: \.self) { plugin in
                Text(plugin)
                    .onTapGesture {
                        selectedPlugin = plugin // 选择插件
                    }
            }
            
            // 显示选择的插件
            if let selectedPlugin = selectedPlugin {
                Text("已选择插件: \(selectedPlugin)")
            }
            
            // 显示当前首选项启动插件
            if let preferredPlugin = UserDefaults.standard.string(forKey: "preferredPlugin") {
                Text("当前首选项启动插件: \(preferredPlugin)")
                    .padding()
            }
            
            Button("设置为首选项启动插件") {
                if let selectedPlugin = selectedPlugin {
                    setPreferredPlugin(plugin: selectedPlugin)
                }
            }
            .padding()
            
            Button("上传插件") {
                uploadPlugin()
            }
            .padding()
        }
        .onAppear {
            loadPlugins()
        }
    }
    
    private func loadPlugins() {
        let fileManager = FileManager.default
        // 设置插件目录为应用支持目录下的 plugins 文件夹
        guard let pluginDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("plugins") else {
            return
        }
        
        // 检查目录是否存在，如果不存在则创建
        if !fileManager.fileExists(atPath: pluginDirectory.path) {
            do {
                try fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true, attributes: nil)
                print("插件目录已创建：\(pluginDirectory.path)")
            } catch {
                print("创建插件目录时出错：\(error)")
            }
        }
        
        // 加载插件目录下的所有 HTML 文件
        do {
            let files = try fileManager.contentsOfDirectory(at: pluginDirectory, includingPropertiesForKeys: nil)
            plugins = files.map { $0.lastPathComponent }
        } catch {
            print("加载插件时出错：\(error)")
        }
    }
    
    private func uploadPlugin() {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["html"]
        openPanel.begin { result in
            if result == .OK, let url = openPanel.url {
                savePlugin(url: url)
            }
        }
    }
    
    private func savePlugin(url: URL) {
        let fileManager = FileManager.default
        guard let pluginDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("plugins") else {
            return
        }
        
        let destinationURL = pluginDirectory.appendingPathComponent(url.lastPathComponent)
        
        // 检查文件是否已存在
        if fileManager.fileExists(atPath: destinationURL.path) {
            // 弹出确认对话框
            let alert = NSAlert()
            alert.messageText = "文件已存在"
            alert.informativeText = "是否覆盖现有文件？"
            alert.addButton(withTitle: "覆盖")
            alert.addButton(withTitle: "取消")
            
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                return // 用户选择取消
            }
        }
        
        do {
            try fileManager.replaceItemAt(destinationURL, withItemAt: url)
            loadPlugins() // 重新加载插件列表
        } catch {
            print("保存插件时出错：\(error)")
        }
    }
    
    private func setPreferredPlugin(plugin: String) {
        // 保存用户选择的首选项插件
        UserDefaults.standard.set(plugin, forKey: "preferredPlugin")
        print("已设置首选项启动插件为: \(plugin)")
    }
}
