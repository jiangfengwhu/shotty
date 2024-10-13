import AppKit
import SwiftUI
@preconcurrency import WebKit  // 添加此行以导入 WebKit

struct EditView: View {
    @ObservedObject var appState: AppState
    @State var activePluginId: String =
        (UserDefaults.standard.string(
            forKey: "preferredPlugin") ?? "")
    var body: some View {
        ZStack {
            WebView(pluginID: $activePluginId, webView: appState.webview)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack {
                        Menu {
                            ForEach(appState.plugins, id: \.self) { plugin in
                                Button(action: {
                                    activePluginId = plugin
                                }) {
                                    Text(plugin)
                                    if activePluginId == plugin {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "puzzlepiece")
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Color.gray.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            // appState.reloadWebView()
                            appState.showToast(
                                message: "Reloading..." + UUID().uuidString
                            )
                            self.activePluginId = "http://localhost:5173/"
                        }) {
                            Image(systemName: "arrow.up.doc")
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Color.gray.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WebView: View {
    @Binding var pluginID: String
    var webView: WKWebView

    var body: some View {
        WebViewWrapper(pluginID: pluginID, webView: webView)
    }
}

struct WebViewWrapper: NSViewRepresentable {
    let pluginID: String
    var webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator  // 添加 UI 代理
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        webView.configuration.preferences.setValue(
            true, forKey: "allowFileAccessFromFileURLs")
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if context.coordinator.lastLoadedHTML != pluginID {  // 检查 HTML 是否变化
            if pluginID.lowercased().hasPrefix("http://")
                || pluginID.lowercased().hasPrefix("https://")
            {
                // 如果是URL,直接加载网页
                if let url = URL(string: pluginID) {
                    nsView.load(URLRequest(url: url))
                }
            } else {
                let pluginDirectory = Constants.pluginDirectory
                    .appendingPathComponent(pluginID)
                nsView.loadFileURL(
                    pluginDirectory.appendingPathComponent("index.html"),
                    allowingReadAccessTo: pluginDirectory)
            }
            context.coordinator.lastLoadedHTML = pluginID  // 更新已加载的 HTML
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler,
        WKUIDelegate
    {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        }
        
        var parent: WebViewWrapper
        var lastLoadedHTML: String = ""  // 将 lastLoadedHTML 移到 Coordinator

        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }

        // 实现 WKUIDelegate 方法来处理文件选择
        func webView(
            _ webView: WKWebView,
            runOpenPanelWith parameters: WKOpenPanelParameters,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping ([URL]?) -> Void
        ) {
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = true
            openPanel.allowsMultipleSelection =
                parameters.allowsMultipleSelection
            openPanel.canChooseDirectories = false

            openPanel.begin { result in
                if result == .OK {
                    completionHandler(openPanel.urls)
                } else {
                    completionHandler(nil)
                }
            }
        }

        // 添加以下方法来处理下载
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url,
                navigationAction.navigationType == .linkActivated
            {
                // 检查是否为下载链接
                if isDownloadableFile(url: url) {
                    decisionHandler(.cancel)
                    downloadFile(from: url)
                } else {
                    decisionHandler(.allow)
                }
            } else {
                decisionHandler(.allow)
            }
        }

        private func isDownloadableFile(url: URL) -> Bool {
            // 这里可以根据文件扩展名或MIME类型来判断是否为可下载文件
            let downloadableExtensions = [
                "pdf", "zip", "doc", "docx", "xls", "xlsx", "png", "jpg",
                "jpeg", "gif", "bmp", "tiff", "webp",
            ]
            return downloadableExtensions.contains(
                url.pathExtension.lowercased())
        }

        private func downloadFile(from url: URL) {
            let downloadTask = URLSession.shared.downloadTask(with: url) {
                (tempLocalUrl, response, error) in
                if let tempLocalUrl = tempLocalUrl, error == nil {
                    if let statusCode = (response as? HTTPURLResponse)?
                        .statusCode
                    {
                        print("成功下载。状态码: \(statusCode)")
                    }

                    // 获取建议的文件名
                    let suggestedFilename =
                        response?.suggestedFilename ?? url.lastPathComponent

                    // 创建保存面板
                    DispatchQueue.main.async {
                        let savePanel = NSSavePanel()
                        savePanel.canCreateDirectories = true
                        savePanel.showsTagField = false
                        savePanel.nameFieldStringValue = suggestedFilename
                        savePanel.begin { (result) in
                            if result == .OK {
                                if let destinationUrl = savePanel.url {
                                    do {
                                        try FileManager.default.moveItem(
                                            at: tempLocalUrl, to: destinationUrl
                                        )
                                        print("文件已保存到: \(destinationUrl.path)")
                                    } catch {
                                        Shotty.Utils.showToast(
                                            message: "\("保存文件失败".localized): \(error.localizedDescription)"
                                        )
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Shotty.Utils.showToast(
                        message: "\("下载文件失败".localized): \(error?.localizedDescription ?? "\("未知错误".localized)")"
                    )
                }
            }
            downloadTask.resume()
        }
    }
}
