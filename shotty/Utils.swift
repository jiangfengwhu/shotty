import AppKit
import SwiftUICore
func showSettingsWindow() {
    if #available(macOS 14.0, *) {
        @Environment(\.openSettings) var openSettings
        openSettings()
    }
    else if #available(macOS 13.0, *) {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
    else {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}
