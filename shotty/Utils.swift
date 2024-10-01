import AppKit
import SwiftUICore

enum Shotty {
    enum Utils {
        static func showSettingsWindow() {
            if #available(macOS 14.0, *) {
                @Environment(\.openSettings) var openSettings
                openSettings()
            } else if #available(macOS 13.0, *) {
                NSApp.sendAction(
                    Selector(("showSettingsWindow:")), to: nil, from: nil)
            } else {
                NSApp.sendAction(
                    Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
        }

        static func selectHTMLFile(done: @escaping (URL) -> Void) {
            let openPanel = NSOpenPanel()
            openPanel.allowedFileTypes = ["html"]
            openPanel.begin { result in
                if result == .OK, let url = openPanel.url {
                    done(url)
                }
            }
        }

        static func loadHTMLFile(done: @escaping (String?) -> Void) {
            selectHTMLFile { url in
                do {
                    let htmlContent = try String(
                        contentsOf: url, encoding: .utf8)
                    done(htmlContent)
                } catch {
                    print("读取 HTML 文件时出错：\(error)")
                    done(nil)
                }
            }
        }

        static func loadPluginHTMLByID(
            pluginID: String, done: @escaping (String?) -> Void
        ) {
            let fileManager = FileManager.default
            guard
                let pluginDirectory = fileManager.urls(
                    for: .applicationSupportDirectory, in: .userDomainMask
                ).first?.appendingPathComponent("plugins")
            else {
                return
            }
            let pluginURL = pluginDirectory.appendingPathComponent(
                pluginID)
            do {
                let htmlContent = try String(
                    contentsOf: pluginURL, encoding: .utf8)
                done(htmlContent)
            } catch {
                print("插件 HTML 时出错：\(error)")
                done(nil)
            }
        }
    }
    enum ImageUtils {
        static func saveImageToDownloads(image: NSImage) {
            guard let data = image.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: data),
                let pngData = bitmap.representation(
                    using: .png, properties: [:])
            else {
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
                        print("像已保存到：\(url.path)")
                    } catch {
                        print("保存图像时出错：\(error)")
                    }
                }
            }
        }
        static func saveBase64Image(base64String: String) {
            let components = base64String.components(separatedBy: ",")
            guard components.count > 1,
                let imageData = Data(base64Encoded: components[1])
            else { return }
            guard let image = NSImage(data: imageData) else {
                return
            }

            saveImageToDownloads(image: image)
        }
    }
    enum JS {
        static func genInitJSTag(imageBase64: String) -> String {
            return """
                <script>
                window.shottyImageBase64 = '\(imageBase64)';
                window.saveShottyImage = window.webkit.messageHandlers.saveBase64ImageHandler.postMessage;
                </script>
                """
        }
        static func genImageChangeJS(imageBase64: String) -> String {
            return """
                window.onShottyImage && window.onShottyImage('\(imageBase64)');
                """
        }
    }
}
