import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        VStack {
            if let image = viewModel.capturedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Text("尚未截图")
            }
            
            Button("关闭") {
                // 隐藏窗口而不是关闭
                NSApplication.shared.keyWindow?.orderOut(nil)
            }
            
            Button("保存") {
                if let image = viewModel.capturedImage {
                    saveImageToDownloads(image: image)
                }
            }
        }
        .padding()
        .frame(minWidth: 300, minHeight: 300) // 修改为可调整大小
    }
    
    private func saveImageToDownloads(image: NSImage) {
        guard let data = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }
        
        // 使用 NSSavePanel 选择保存位置
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["png"]
        savePanel.nameFieldStringValue = "screenshot.png"
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try pngData.write(to: url)
                    print("图像已保存到：\(url.path)")
                } catch {
                    print("保存图像时出错：\(error)")
                }
            }
        }
    }
}
