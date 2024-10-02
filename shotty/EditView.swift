import AppKit
import SwiftUI
@preconcurrency import WebKit  // 添加此行以导入 WebKit

struct EditView: View {
    @ObservedObject var appState: AppState
    @State var htmlString = ""
    @State var activePluginId: String = (UserDefaults.standard.string(
        forKey: "preferredPlugin") ?? "")
    var body: some View {
        ZStack {
            WebView(html: $htmlString, image: $appState.capturedImage)
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
                                    loadPluginHTML()
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
                            self.htmlString = "http://localhost:5173/"
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
        .onAppear {
            loadPluginHTML()
        }
    }

    private func loadPluginHTML() {
        Shotty.Utils.loadPluginHTMLByID(pluginID: activePluginId) {
            htmlContent in
            if let htmlContent = htmlContent {
                self.htmlString = htmlContent
            }
        }
    }
}

struct WebView: View {
    @Binding var html: String
    @Binding var image: NSImage?  // 更改为绑定状态

    var body: some View {
        WebViewWrapper(html: html, image: image)  // 传递图像
    }
}

struct WebViewWrapper: NSViewRepresentable {
    let html: String
    var image: NSImage?  // 添加图像属性

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator  // 添加 UI 代理
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        } else {
            // Fallback on earlier versions
        }
        let contentController = webView.configuration.userContentController
        contentController.add(
            context.coordinator, name: "saveBase64ImageHandler")
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let base64String =
            image?.tiffRepresentation?.base64EncodedString() ?? ""
        let initJS = Shotty.JS.genInitJSTag(imageBase64: base64String)

        if context.coordinator.lastLoadedHTML != html {  // 检查 HTML 是否变化
            if html.lowercased().hasPrefix("http://") || html.lowercased().hasPrefix("https://") {
                // 如果是URL,直接加载网页
                if let url = URL(string: html) {
                    nsView.load(URLRequest(url: url))
                }
            } else {
                // 如果不是URL,加载HTML字符串
                nsView.loadHTMLString(initJS + html, baseURL: nil)
            }
            context.coordinator.lastLoadedHTML = html  // 更新已加载的 HTML
        }

        nsView.evaluateJavaScript(
            Shotty.JS.genImageChangeJS(imageBase64: base64String)
        ) { (result, error) in
            if let error = error {
                print("JavaScript 执行出错：\(error.localizedDescription)")  // 打印错误信息
            } else {
                print("JavaScript 执行成功，结果：\(String(describing: result))")  // 打印执行结果
            }
        }  // 确保在加载后执行
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler,
        WKUIDelegate
    {
        var parent: WebViewWrapper
        var lastLoadedHTML: String = ""  // 将 lastLoadedHTML 移到 Coordinator

        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }

        // 处理 JavaScript 脚本消息
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == "saveBase64ImageHandler",
                let base64String = message.body as? String
            {
                // 调用保存 Base64 图像的方法
                Shotty.ImageUtils.saveBase64Image(base64String: base64String)  // 调用父视图的方法
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
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               navigationAction.navigationType == .linkActivated {
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
            let downloadableExtensions = ["pdf", "zip", "doc", "docx", "xls", "xlsx", "png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp"]
            return  downloadableExtensions.contains(url.pathExtension.lowercased())
        }

        private func downloadFile(from url: URL) {
            let downloadTask = URLSession.shared.downloadTask(with: url) { (tempLocalUrl, response, error) in
                if let tempLocalUrl = tempLocalUrl, error == nil {
                    if let statusCode = (response as? HTTPURLResponse)?.statusCode {
                        print("成功下载。状态码: \(statusCode)")
                    }
                    
                    // 获取建议的文件名
                    let suggestedFilename = response?.suggestedFilename ?? url.lastPathComponent
                    
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
                                        try FileManager.default.moveItem(at: tempLocalUrl, to: destinationUrl)
                                        print("文件已保存到: \(destinationUrl.path)")
                                    } catch {
                                        print("保存文件时出错: \(error.localizedDescription)")
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