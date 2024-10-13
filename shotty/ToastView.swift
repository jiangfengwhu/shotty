import SwiftUI

struct ToastView: View {
    @ObservedObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if let message = appState.toastMessage, appState.showToast {
            VStack {
                HStack {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 35, height: 35)
                    Text(message)
                        .bold()
                        .lineLimit(nil)
                }
                .padding()
                .background(
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        .cornerRadius(25)
                )
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .cornerRadius(25)
            }
            .frame(width: 300, alignment: .bottom)
            .padding(20)
            .shadow(color: .gray.opacity(0.5), radius: 5, x: 0, y: 5)
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}
