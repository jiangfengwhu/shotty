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
        }
        .padding()
        .frame(width: 300, height: 300)
    }
}
