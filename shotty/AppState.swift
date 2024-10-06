import AppKit
import SwiftUI

class AppState: ObservableObject {
    @Published var capturedImage: NSImage?
    @Published var plugins: [String] = []
    var contentWindow: NSWindow?
    var statusBar: StatusBarController?
    var delegate: AppDelegate?
    var isWindowOpen: Bool = false {
        didSet {
            updateDockIconVisibility()
        }
    }

    func setDelegate(delegate: AppDelegate) {
        self.delegate = delegate
    }

    func updateDockIconVisibility() {
        NSApp.setActivationPolicy(isWindowOpen ? .regular : .accessory)
    }

    @MainActor func initStatusBar() {
        statusBar = StatusBarController()
        statusBar?.captureAction = captureScreen
        statusBar?.openContentViewAction = showContentWindow
        statusBar?.openSettingsAction = openSettings  // 添加设置窗口的操作
        statusBar?.updateMenuShortcuts()
    }

    func openSettings() {
        Shotty.Utils.showSettingsWindow()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func captureScreen() {
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-ic"]  // -i 交互式, -c 复制到剪贴板

        task.launch()
        task.waitUntilExit()

        // 从剪贴板读取图像
        if let image = NSPasteboard.general.readObjects(
            forClasses: [NSImage.self], options: nil)?.first as? NSImage
        {
            print("成功从剪贴板读取截图")
            capturedImage = image
            showContentWindow()
        } else {
            print("无法从剪贴板读取截图")
        }
    }

    func showContentWindow() {
        if contentWindow == nil {
            let contentView = EditView(appState: self)
            let screenSize =
                NSScreen.main?.frame.size ?? CGSize(width: 1200, height: 1000)
            contentWindow = NSWindow(
                contentRect: NSRect(
                    x: 0, y: 0, width: screenSize.width / 2,
                    height: screenSize.height / 2),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            contentWindow?.title = "截图结果"
            contentWindow?.contentView = NSHostingView(rootView: contentView)
            contentWindow?.delegate = delegate
            contentWindow?.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        contentWindow?.makeKeyAndOrderFront(nil)
        isWindowOpen = true  // 更新窗口状态
    }

    func closeContentWindow() {
        contentWindow?.orderOut(nil)
        isWindowOpen = false  // 更新窗口状态
    }

    func reloadPlugins() {
        let fileManager = FileManager.default
        // 设置插件目录为应用支持目录下的 plugins 文件夹
        let pluginDirectory = Constants.pluginDirectory

        // 加载插件目录下的所有目录
        do {
            let files = try fileManager.contentsOfDirectory(
                at: pluginDirectory, includingPropertiesForKeys: nil)
            plugins = files.filter { $0.hasDirectoryPath }.map {
                $0.lastPathComponent
            }
        } catch {
            print("加载插件时出错：\(error)")
        }
    }

    func savePlugin(url: URL) {
        let fileManager = FileManager.default
        let pluginDirectory = Constants.pluginDirectory

        let destinationURL = pluginDirectory.appendingPathComponent(
            url.lastPathComponent)

        // 复制文件到目标路径，如果文件已存在则覆盖
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                // 弹出确认对话框
                let alert = NSAlert()
                alert.messageText = "插件已存在"
                alert.informativeText = "是否覆盖现有插件？"
                alert.addButton(withTitle: "覆盖")
                alert.addButton(withTitle: "取消")

                let response = alert.runModal()
                if response == .alertSecondButtonReturn {
                    return  // 用户选择取消
                }
                try fileManager.removeItem(at: destinationURL)  // 删除已存在的文件
            }
            try fileManager.copyItem(at: url, to: destinationURL)
            reloadPlugins()  // 重新加载插件列表
        } catch {
            print("保存插件时出错：\(error.localizedDescription)")
        }
    }

    func setPreferredPlugin(plugin: String) {
        // 保存用户选择的首选项插件
        UserDefaults.standard.set(plugin, forKey: "preferredPlugin")
    }

    func isDefaultPlugin(plugin: String) -> Bool {
        return plugin == UserDefaults.standard.string(forKey: "preferredPlugin")
    }

    func checkAndCopyDefaultPlugin() {
        let fileManager = FileManager.default
        let pluginDirectory = Constants.pluginDirectory

        // 检查目录是否存在，如果不存在则创建
        if !fileManager.fileExists(atPath: pluginDirectory.path) {
            do {
                try fileManager.createDirectory(
                    at: pluginDirectory, withIntermediateDirectories: true,
                    attributes: nil)
                print("插件目录已创建：\(pluginDirectory.path)")
            } catch {
                print("创建插件目录时出错：\(error)")
            }
        }

        let destinationURL = pluginDirectory.appendingPathComponent(
            Constants.defaultPluginName)

        // 检查插件目录中是否存在 shotty目录
        if !fileManager.fileExists(atPath: destinationURL.path) {
            // 如果不存在,从 bundle 中复制
            if let bundleURL = Bundle.main.url(
                forResource: "shotty", withExtension: nil
            ) {
                do {
                    try fileManager.copyItem(at: bundleURL, to: destinationURL)
                    setPreferredPlugin(plugin: Constants.defaultPluginName)
                    print("默认插件已复制到: \(destinationURL.path)")
                } catch {
                    print("复制默认插件时出错: \(error)")
                }
            } else {
                print("在 bundle 中未找到默认插件")
            }
        }
    }
}
