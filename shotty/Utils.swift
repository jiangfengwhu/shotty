import AppKit
import SwiftUICore
import ZIPFoundation

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
                    print("无法恢复书签：\(error)")
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
                print("保存书签数据失败: \(error.localizedDescription)", url)

                // 检查 URL 是否可访问
                if url.startAccessingSecurityScopedResource() {
                    print("URL 可以访问")
                    url.stopAccessingSecurityScopedResource()
                } else {
                    print("无法访问 URL")
                }
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
            let pluginDirectory = Constants.pluginDirectory
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
                    try pngData.write(to: dir.appendingPathComponent(fileName))
                    if closeWindow {
                        Shotty.Utils.closeWindow()
                    }
                } catch {
                    print("保存图像时出错：\(error)")
                }
            } else {
                Shotty.Utils.selectDirectory { url in
                    let savePath = url.appendingPathComponent(fileName)
                    do {
                        try pngData.write(to: savePath)
                        print("像已保存到：\(savePath.path)")
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
                        print("保存图像时出错：\(error)")
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
                    print("更新成功安装")

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
