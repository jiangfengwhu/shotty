import AppKit
import SwiftUI
@preconcurrency import WebKit  // 添加此行以导入 WebKit

struct EditView: View {
    @ObservedObject var appState: AppState
    @State var htmlString = ""

    var body: some View {
        VStack {
            WebView(html: $htmlString, image: $appState.capturedImage)  // 传递状态图像
                .frame(
                    minWidth: 0, maxWidth: .infinity, minHeight: 0,
                    maxHeight: .infinity)

            Button("上传 HTML 文件") {
                Shotty.Utils.loadHTMLFile { htmlContent in
                    if let htmlContent = htmlContent {
                        self.htmlString = htmlContent
                    }
                }
            }
        }
        .onAppear {
            loadPreferredPluginHTML()  // 在视图出现时加载首选项插件的 HTML
        }
    }

    private func loadPreferredPluginHTML() {
        if let preferredPlugin = UserDefaults.standard.string(
            forKey: "preferredPlugin")
        {
            Shotty.Utils.loadPluginHTMLByID(pluginID: preferredPlugin) {
                htmlContent in
                if let htmlContent = htmlContent {
                    self.htmlString = htmlContent
                }
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
            nsView.loadHTMLString(initJS + html, baseURL: nil)  // 加载 HTML 字符串
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

        // 添加以下方法来处理文件下载
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            if let response = navigationResponse.response as? HTTPURLResponse,
                let url = navigationResponse.response.url,
                let disposition = response.allHeaderFields[
                    "Content-Disposition"] as? String
            {

                if disposition.contains("attachment") {
                    decisionHandler(.cancel)

                    let downloadTask = URLSession.shared.downloadTask(with: url)
                    { localURL, urlResponse, error in
                        if let localURL = localURL {
                            DispatchQueue.main.async {
                                let savePanel = NSSavePanel()
                                savePanel.nameFieldStringValue =
                                    url.lastPathComponent
                                savePanel.begin { result in
                                    if result == .OK,
                                        let saveURL = savePanel.url
                                    {
                                        do {
                                            try FileManager.default.moveItem(
                                                at: localURL, to: saveURL)
                                            print("文件已成功下载并保存到：\(saveURL.path)")
                                        } catch {
                                            print(
                                                "保存文件时出错：\(error.localizedDescription)"
                                            )
                                        }
                                    }
                                }
                            }
                        } else if let error = error {
                            print("下载文件时出错：\(error.localizedDescription)")
                        }
                    }
                    downloadTask.resume()
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}
