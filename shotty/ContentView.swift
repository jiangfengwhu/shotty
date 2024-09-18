import SwiftUI
import AppKit

struct ContentView: View {
    @State private var isCapturing = false
    @State private var capturedImage: NSImage?
    
    var body: some View {
        VStack {
            if let image = capturedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Text("尚未截图")
            }
            
            Button(action: captureScreen) {
                Text("开始截图")
            }
        }
        .padding()
    }
    
    func captureScreen() {
        isCapturing = true
        hideWindow()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let task = Process()
            task.launchPath = "/usr/sbin/screencapture"
            task.arguments = ["-ic"]  // -i 交互式, -c 复制到剪贴板
            
            task.launch()
            task.waitUntilExit()
            
            // 从剪贴板读取图像
            if let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                capturedImage = image
                print("成功从剪贴板读取截图")
                showWindow()
            } else {
                print("无法从剪贴板读取截图")
                // 如果截图失败，也显示窗口以便用户知道结果
                showWindow()
            }
            
            isCapturing = false
        }
    }
    
    func hideWindow() {
        NSApplication.shared.hide(nil)
    }
    
    func showWindow() {
        NSApplication.shared.unhide(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
