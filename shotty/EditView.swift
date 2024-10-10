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
            WebView(
                pluginID: $activePluginId, image: $appState.capturedImage,
                saveDirectory: $appState.saveDirectory,
                dismiss: appState.closeContentWindow
            )
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
                            self.activePluginId = "http://localhost:5173/"
                            // Shotty.Utils.loadHTMLFile { htmlContent in
                            //     if let htmlContent = htmlContent {
                            //         self.htmlString = htmlContent
                            //     }
                            // }
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
    @Binding var image: NSImage?
    @Binding var saveDirectory: URL?
    var dismiss: () -> Void

    var body: some View {
        WebViewWrapper(
            pluginID: pluginID, dismiss: dismiss, image: image, saveDirectory: saveDirectory)  // 传递图像
    }
}

struct WebViewWrapper: NSViewRepresentable {
    let pluginID: String
    var dismiss: () -> Void

    var image: NSImage?
    var saveDirectory: URL?
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator  // 添加 UI 代理
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        } else {
            // Fallback on earlier versions
        }
        webView.configuration.preferences.setValue(
            true, forKey: "allowFileAccessFromFileURLs")
        let contentController = webView.configuration.userContentController
        contentController.add(
            context.coordinator, name: "saveBase64ImageHandler")
        contentController.add(
            context.coordinator, name: "hideContentViewHandler")
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.updateSaveDirectory(url: saveDirectory)
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
        if context.coordinator.lastImage != image {
            context.coordinator.lastImage = image
            let base64String =
                image?.tiffRepresentation?.base64EncodedString() ?? ""
            nsView.evaluateJavaScript(
                Shotty.JS.genImageChangeJS(imageBase64: base64String)
            ) { (result, error) in
                if let error = error {
                    print("JavaScript 执行出错：\(error.localizedDescription)")  // 打印错误信息
                } else {
                    print("JavaScript 执行成功，结果：\(String(describing: result))")  // 打印执行结果
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler,
        WKUIDelegate
    {
        var parent: WebViewWrapper
        var lastLoadedHTML: String = ""  // 将 lastLoadedHTML 移到 Coordinator
        var lastImage: NSImage?
        var saveDirectory: URL?

        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }

        func updateSaveDirectory(url: URL?) {
            saveDirectory = url
        }

        // 处理 JavaScript 脚本消息
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == "saveBase64ImageHandler",
                let params = message.body as? [String: Any]
            {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
                let dateString = dateFormatter.string(from: Date())
                // 调用保存 Base64 图像的方法
                Shotty.ImageUtils.saveBase64Image(
                    base64String: params["base64String"] as? String ?? "",
                    dir: saveDirectory,
                    fileName: "shotty-" + dateString + ".png",
                    closeWindow: params["closeWindow"] as? Bool ?? true
                )  // 调用父视图的方法
            }
            if message.name == "hideContentViewHandler" {
                parent.dismiss()
            }
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
                                        print(
                                            "保存文件时出错: \(error.localizedDescription)"
                                        )
                                    }
                                }
                            }
                        }
                    }
                } else {
                    print("下载文件时出错: \(error?.localizedDescription ?? "未知错误")")
                }
            }
            downloadTask.resume()
        }
    }
}
