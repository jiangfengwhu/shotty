import SwiftUI
import AppKit
import WebKit // 添加此行以导入 WebKit

struct ContentView: View {
    @ObservedObject var appState: AppState
    @State var htmlString = ""
    
    var body: some View {
        VStack {
            
            TextField("", text: $htmlString)
            
            Divider()
            
            // 使用首选项插件的 HTML 内容
            WebView(html: $htmlString, image: $appState.capturedImage) // 传递状态图像
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            Button("关闭") {
                // 隐藏窗口而不是关闭
                // NSApplication.shared.keyWindow?.orderOut(nil)
                appState.closeContentWindow()
            }
            
            Button("保存") {
                if let image = appState.capturedImage {
                    saveImageToDownloads(image: image)
                }
            }
            
            Button("上传 HTML 文件") {
                let openPanel = NSOpenPanel()
                openPanel.allowedFileTypes = ["html"]
                openPanel.begin { result in
                    if result == .OK, let url = openPanel.url {
                        do {
                            let htmlContent = try String(contentsOf: url, encoding: .utf8)
                            self.htmlString = htmlContent // 更新文本字段为上传的 HTML 内容
                        } catch {
                            print("读取 HTML 文件时出错：\(error)")
                        }
                    }
                }
            }
        }
        .onAppear {
            loadPreferredPluginHTML() // 在视图出现时加载首选项插件的 HTML
        }
        .padding()
        .frame(minWidth: 600, minHeight: 600) // 修改为可调整大小
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PluginUpdated"))) { _ in
            loadPreferredPluginHTML()
        }
    }
    
    private func loadPreferredPluginHTML() {
        let fileManager = FileManager.default
        guard let pluginDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("plugins") else {
            return
        }
        
        // 获取首选项插件名称
        if let preferredPlugin = UserDefaults.standard.string(forKey: "preferredPlugin") {
            let pluginURL = pluginDirectory.appendingPathComponent(preferredPlugin)
            
            // 读取插件的 HTML 内容
            do {
                let htmlContent = try String(contentsOf: pluginURL, encoding: .utf8)
                self.htmlString = htmlContent // 更新 ViewModel 中的 HTML 内容
            } catch {
                print("加载首选项插件 HTML 时出错：\(error)")
            }
        }
    }
}

struct WebView: View {
    @Binding var html: String
    @Binding var image: NSImage? // 更改为绑定状态
    
    var body: some View {
        WebViewWrapper(html: html, image: image) // 传递图像
    }
}

struct WebViewWrapper: NSViewRepresentable {
    let html: String
    var image: NSImage? // 添加图像属性
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator // 设置导航代理
        let contentController = webView.configuration.userContentController
        contentController.add(context.coordinator, name: "saveBase64ImageHandler") // 添加保存 Base64 图像处理器
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        
        
        if let image = image, let imageData = image.tiffRepresentation {
            // 将图像数据加载到 WebView ���
            let base64String = imageData.base64EncodedString()
            // 仅在 html 发生变化时重新加载
            if context.coordinator.lastLoadedHTML != html { // 检查 HTML 是否变化
                let initJS = """
            <script>
            window.shottyImageBase64 = '\(base64String)';
            window.saveShottyImage = window.webkit.messageHandlers.saveBase64ImageHandler.postMessage;
            </script>
            """
                nsView.loadHTMLString(initJS + html, baseURL: nil) // 加载 HTML 字符串
                context.coordinator.lastLoadedHTML = html // 更新已加载的 HTML
            }
            
            // 将图像数据挂载到 JavaScript 上下文
            let js = """
            window.onShottyImage && window.onShottyImage('\(base64String)');
            """
            nsView.evaluateJavaScript(js) { (result, error) in
                if let error = error {
                    print("JavaScript 执行出错：\(error.localizedDescription)") // 打印错误信息
                } else {
                    print("JavaScript 执行成功，结果：\(String(describing: result))") // 打印执行结果
                }
            } // 确保在加载后执行
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebViewWrapper
        var lastLoadedHTML: String = "" // 将 lastLoadedHTML 移到 Coordinator
        
        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }
        
        // 捕获 JavaScript 执行错误
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("加载失败：\(error.localizedDescription)") // 打印加载错误
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("导航失败：\(error.localizedDescription)") // 打印导航错误
        }
        
        // 处理 JavaScript 脚本消息
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "saveBase64ImageHandler", let base64String = message.body as? String {
                // 调用保存 Base64 图像的方法
                saveBase64Image(base64String: base64String) // 调用父视图的方法
            }
        }
        
        private func saveBase64Image(base64String: String) {
            let components = base64String.components(separatedBy: ",")
            guard components.count > 1, let imageData = Data(base64Encoded: components[1]) else { return }
            guard let image = NSImage(data: imageData) else { 
                return 
            }
            
            saveImageToDownloads(image: image)
        }
    }
}
