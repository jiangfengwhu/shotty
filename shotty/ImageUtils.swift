//
//  ImageUtils.swift
//  shotty
//
//  Created by Feng Jiang on 2024/9/26.
//

import AppKit

public func saveImageToDownloads(image: NSImage) {
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
                print("像已保存到：\(url.path)")
            } catch {
                print("保存图像时出错：\(error)")
            }
        }
    }
}
