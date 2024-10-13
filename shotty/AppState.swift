import AppKit
import SwiftUI
import WebKit

class AppState: ObservableObject {
    @Published var capturedImage: NSImage?
    @Published var plugins: [String] = []
    @Published var saveDirectory: URL?

    var webview: WKWebView = WKWebView()
    var contentWindow: NSWindow?
    var toastWindow: NSWindow?
    private var hideToastWorkItem: DispatchWorkItem?
    var statusBar: StatusBarController?
    var delegate: AppDelegate?
    var isWindowOpen: Bool = false {
        didSet {
            updateDockIconVisibility()
        }
    }

    @Published var toastMessage: String?
    @Published var showToast: Bool = false

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

    func initContentWindow() {
        let contentView = EditView(appState: self)
        let screenSize =
            NSScreen.main?.frame.size ?? CGSize(width: 1200, height: 1000)
        contentWindow = NSWindow(
            contentRect: NSRect(
                x: 0, y: 0, width: screenSize.width * 0.67,
                height: screenSize.height * 0.67),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        contentWindow?.title = "Shotty".localized
        contentWindow?.contentView = NSHostingView(rootView: contentView)
        contentWindow?.delegate = delegate
        contentWindow?.center()
    }

    func showContentWindow() {
        if contentWindow == nil {
            initContentWindow()
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
            showToast(message: "\("加载插件失败".localized): \(error.localizedDescription)")
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
                alert.messageText = "插件已存在".localized
                alert.informativeText = "是否覆盖现有插件".localized + "?"
                alert.addButton(withTitle: "覆盖".localized)
                alert.addButton(withTitle: "取消".localized)

                let response = alert.runModal()
                if response == .alertSecondButtonReturn {
                    return  // 用户选择取消
                }
                try fileManager.removeItem(at: destinationURL)  // 删除已存在的文件
            }
            try fileManager.copyItem(at: url, to: destinationURL)
            reloadPlugins()  // 重新加载插件列表
        } catch {
            showToast(message: "\("保存插件失败".localized): \(error.localizedDescription)")
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
                showToast(message: "\("创建插件目录失败".localized): \(error.localizedDescription)")
            }
        }

        let destinationURL = pluginDirectory.appendingPathComponent(
            Constants.defaultPluginName)

        // 检查插件目录中是否存在 shotty目录
        if !fileManager.fileExists(atPath: destinationURL.path) {
            // 如果不存在,从 bundle 中复制
            if let bundleURL = Bundle.main.url(
                forResource: Constants.defaultPluginName, withExtension: nil
            ) {
                do {
                    try fileManager.copyItem(at: bundleURL, to: destinationURL)
                    setPreferredPlugin(plugin: Constants.defaultPluginName)
                    print("默认插件已复制到: \(destinationURL.path)")
                } catch {
                    showToast(message: "\("复制默认插件失败".localized): \(error.localizedDescription)")
                }
            } else {
                showToast(message: "\("在 bundle 中未找到默认插件".localized)")
            }
        }
    }

    func setSaveDirectory(directory: URL) {
        if let dir = Shotty.Utils.saveSaveDirectoryBookmark(url: directory) {
            saveDirectory = dir
        }
    }

    func initSaveDirectory() {
        let dir = Shotty.Utils.initSaveDirectory()
        if let dir = dir {
            saveDirectory = dir
        }
    }

    func reloadWebView() {
        webview.reload()
    }

    func showToast(message: String, delay: TimeInterval = 2) {
        hideToastWorkItem?.cancel()

        self.toastMessage = message
        self.showToast = true
        self.displayToastWindow()

        let workItem = DispatchWorkItem { [weak self] in
            self?.hideToast()
        }
        self.hideToastWorkItem = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func hideToast() {
        DispatchQueue.main.async {
            self.toastWindow?.orderOut(nil)
            self.showToast = false
        }
    }

    func displayToastWindow() {
        if toastWindow == nil {
            let toastView = ToastView(appState: self)
            let hostingView = NSHostingView(rootView: toastView)

            let rect = CGRect(x: 0, y: 0, width: 340, height: 100)
            toastWindow = NSWindow(
                contentRect: rect,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            toastWindow?.contentView = hostingView
            toastWindow?.backgroundColor = .clear
            toastWindow?.isOpaque = false
            toastWindow?.hasShadow = false
            toastWindow?.level = .floating
            toastWindow?.ignoresMouseEvents = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {[weak self] in
            guard let self = self, let toastWindow = self.toastWindow else { return }
            toastWindow.setContentSize(toastWindow.contentView?.fittingSize ?? .zero)
            if let screen = NSScreen.main {
                let screenRect = screen.visibleFrame
                let toastRect = toastWindow.frame
                let newOrigin = NSPoint(
                    x: screenRect.midX - toastRect.width / 2 - 20,
                    y: screenRect.maxY - toastRect.height
                )
                toastWindow.setFrameOrigin(newOrigin)
            }
            toastWindow.orderFront(nil)
        }
    }
}
