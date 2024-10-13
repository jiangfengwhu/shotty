import AppKit
import SwiftUICore
import ZIPFoundation
extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}
enum Shotty {
    enum Utils {
        static func initSaveDirectory() -> URL? {
            if let bookmarkData = UserDefaults.standard.data(forKey: "SaveDirectoryBookmark") {

                do {
                    var isStale = false
                    let url = try URL(
                        resolvingBookmarkData: bookmarkData, options: .withSecurityScope,
                        relativeTo: nil, bookmarkDataIsStale: &isStale)

                    if !isStale {
                        _ = url.startAccessingSecurityScopedResource()
                        return url
                    } else {
                        let _ = saveSaveDirectoryBookmark(url: url)
                    }
                } catch {
                    showToast(message: "\("书签恢复失败：".localized)\(error.localizedDescription)")
                }
            }
            return nil
        }

        static func saveSaveDirectoryBookmark(url: URL) -> URL? {
            do {
                let bookmarkData = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                UserDefaults.standard.set(bookmarkData, forKey: "SaveDirectoryBookmark")
                let _ = url.startAccessingSecurityScopedResource()
                print("成功保存书签数据")
                return url
            } catch {
                showToast(message: "\("保存书签数据失败：".localized)\(error.localizedDescription)")
            }
            return nil
        }

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

        static func selectDirectory(done: @escaping (URL) -> Void) {
            let openPanel = NSOpenPanel()
            openPanel.canChooseDirectories = true
            openPanel.canChooseFiles = false
            openPanel.begin { result in
                if result == .OK, let url = openPanel.url {
                    done(url)
                }
            }
        }


        static func closeWindow() {
            DispatchQueue.main.async {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.appState.closeContentWindow()
                }
            }
        }

        static func refreshWebView() {
            DispatchQueue.main.async {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.appState.reloadWebView()
                }
            }
        }

        static func showToast(message: String, delay: TimeInterval = 2) {
            DispatchQueue.main.async {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.appState.showToast(message: message, delay: delay)
                }
            }
        }
    }

    enum ImageUtils {
        static func saveImage(image: NSImage, dir: URL?, fileName: String, closeWindow: Bool) {
            guard let data = image.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: data),
                let pngData = bitmap.representation(
                    using: .png, properties: [:])
            else {
                return
            }
            if let dir = dir {
                do {
                    let savePath = dir.appendingPathComponent(fileName)
                    try pngData.write(to: savePath)
                    Shotty.Utils.showToast(message: "\("已保存".localized): \(savePath.path)", delay: 5)
                    if closeWindow {
                        Shotty.Utils.closeWindow()
                    }
                } catch {
                    Shotty.Utils.showToast(message: "\("保存失败".localized): \(error.localizedDescription)")
                }
            } else {
                Shotty.Utils.selectDirectory { url in
                    let savePath = url.appendingPathComponent(fileName)
                    do {
                        try pngData.write(to: savePath)
                        Shotty.Utils.showToast(message: "\("已保存".localized): \(savePath.path)", delay: 5)
                        // 调用 appState 中的 setSaveDirectory 方法
                        DispatchQueue.main.async {
                            if let appDelegate = NSApp.delegate as? AppDelegate {
                                appDelegate.appState.setSaveDirectory(directory: url)
                            }
                        }
                        if closeWindow {
                            Shotty.Utils.closeWindow()
                        }
                    } catch {
                        Shotty.Utils.showToast(message: "\("保存失败".localized): \(error.localizedDescription)")
                    }
                }

                // 使用 NSSavePanel 选择保存位置
                // let savePanel = NSSavePanel()
                // savePanel.allowedContentTypes = [.png]
                // savePanel.nameFieldStringValue = path.lastPathComponent

                // savePanel.begin { result in
                //     if result == .OK, let url = savePanel.url {
                //         do {
                //             try pngData.write(to: url)
                //             print("像已保存到：\(url.path)")
                //             Shotty.Utils.saveSaveDirectoryBookmark(url: url)
                //         } catch {
                //             print("保存图像时出错：\(error)")
                //         }
                //     }
                // }
            }
        }
        static func saveBase64Image(
            base64String: String, dir: URL?, fileName: String, closeWindow: Bool = true
        ) {
            let components = base64String.components(separatedBy: ",")
            guard components.count > 1,
                let imageData = Data(base64Encoded: components[1])
            else { return }
            guard let image = NSImage(data: imageData) else {
                return
            }

            saveImage(image: image, dir: dir, fileName: fileName, closeWindow: closeWindow)
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
                window.shottyImageBase64 = '\(imageBase64)';
                window.onShottyImage && window.onShottyImage('\(imageBase64)');
                """
        }
    }
    enum UpdateUtils {
        static func checkForUpdates() {
            guard let url = URL(string: "http://120.46.72.66/shotty.zip") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"

            URLSession.shared.dataTask(with: request) { _, response, error in
                guard let httpResponse = response as? HTTPURLResponse,
                    let etag: String = httpResponse.allHeaderFields["Etag"] as? String,
                    error == nil
                else {
                    print("检查更新失败")
                    return
                }

                let currentETag = UserDefaults.standard.string(forKey: "LastETag") ?? ""

                if etag != currentETag {
                    print("etag", etag)
                    downloadAndInstallUpdate(from: url, newETag: etag)
                } else {
                    print("没有可用更新")
                }
            }.resume()
        }
        static func downloadAndInstallUpdate(from url: URL, newETag: String) {
            URLSession.shared.downloadTask(with: url) { localURL, _, error in
                guard let localURL = localURL, error == nil else {
                    print("下载更新失败")
                    return
                }

                do {
                    let pluginDirectory = Constants.pluginDirectory.appendingPathComponent(
                        Constants.defaultPluginName)
                    if FileManager.default.fileExists(atPath: pluginDirectory.path) {
                        try FileManager.default.removeItem(at: pluginDirectory)
                    }
                    try FileManager.default.unzipItem(at: localURL, to: Constants.pluginDirectory)

                    UserDefaults.standard.set(newETag, forKey: "LastETag")
                    Shotty.Utils.showToast(message: "\("更新成功".localized)")

                    Shotty.Utils.refreshWebView()
                } catch {
                    print("安装更新失败: \(error.localizedDescription)")
                }
            }.resume()
        }
        static func startUpdateCheck() {
            let timer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
                checkForUpdates()
            }
            timer.fire()  // 立即执行一次检查
            RunLoop.current.add(timer, forMode: .common)
        }
    }
}
