import SwiftUI
import AppKit
import WebKit // 添加此行以导入 WebKit

struct ContentView: View {
    @ObservedObject var viewModel: ContentViewModel
    @State var text = ""
    @State var capturedImage: NSImage? // 添加状态属性

    var body: some View {
        VStack {

            TextField("", text: $text)
        
            Divider()

            WebView(html: $text, image: $capturedImage) // 传递状态图像
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            Button("关闭") {
                // 隐藏窗口而不是关闭
                NSApplication.shared.keyWindow?.orderOut(nil)
            }
            
            Button("保存") {
                if let image = viewModel.capturedImage {
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
                            self.text = htmlContent // 更新文本字段为上传的 HTML 内容
                        } catch {
                            print("读取 HTML 文件时出错：\(error)")
                        }
                    }
                }
            }
        }
        .onReceive(viewModel.$capturedImage) { image in
            self.capturedImage = image // 更新状态
        }
        .padding()
        .frame(minWidth: 300, minHeight: 300) // 修改为可调整大小
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
        // 仅在 html 发生变化时重新加载
        if context.coordinator.lastLoadedHTML != html { // 检查 HTML 是否变化
            nsView.loadHTMLString(html, baseURL: nil) // 加载 HTML 字符串
            context.coordinator.lastLoadedHTML = html // 更新已加载的 HTML
        }
        
        if let image = image, let imageData = image.tiffRepresentation {
            // 将图像数据加载到 WebView 中
            let base64String = imageData.base64EncodedString()
            // let htmlWithImage = "<html><body><img id='capturedImage' src='data:image/png;base64,\(base64String)'/></body></html>"
            
            
            // 将图像数据挂载到 JavaScript 上下文
            let js = """
            window.shottyImageBase64 = '\(base64String)';
            window.saveShottyImage = window.webkit.messageHandlers.saveBase64ImageHandler.postMessage;
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