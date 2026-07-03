// Saves clipboard image to 90_Inbox/ScreenShots only when the image content changes.
// Long-running watcher: polls NSPasteboard.changeCount every 0.2s (launchd KeepAlive).

import AppKit
import CryptoKit
import Darwin

let saveDir = ("~/00_Home_Local/90_Inbox/ScreenShots" as NSString).expandingTildeInPath
let stateDir = ("~/.local/state/raycast-save-clipboard-image" as NSString).expandingTildeInPath
let lastHashFile = stateDir + "/last_image_sha256"

// Binary plist (boolean true) for com.apple.metadata:kMDItemIsScreenCapture
let screenshotTrueBplistHex = "62706c697374303009080000000000000101000000000000000100000000000000000000000000000009"

func dataFromHex(_ hex: String) -> Data {
    var data = Data()
    var index = hex.startIndex
    while index < hex.endIndex {
        let next = hex.index(index, offsetBy: 2)
        data.append(UInt8(hex[index..<next], radix: 16)!)
        index = next
    }
    return data
}

func pngData(from pb: NSPasteboard) -> Data? {
    if let png = pb.data(forType: .png) { return png }
    if let tiff = pb.data(forType: .tiff),
       let rep = NSBitmapImageRep(data: tiff) {
        return rep.representation(using: .png, properties: [:])
    }
    return nil
}

func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

let xattrValue = dataFromHex(screenshotTrueBplistHex)
try? FileManager.default.createDirectory(atPath: stateDir, withIntermediateDirectories: true)

let pb = NSPasteboard.general
var lastChangeCount = -1
var lastHash = (try? String(contentsOfFile: lastHashFile, encoding: .utf8))?
    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

let formatter = DateFormatter()
formatter.dateFormat = "yyyyMMdd_HHmmss"

while true {
    let count = pb.changeCount
    if count != lastChangeCount {
        lastChangeCount = count
        // Skip when the clipboard also carries a file URL: the image already
        // exists on disk (e.g. CleanShot X saves the file itself and copies it).
        let hasFileURL = pb.types?.contains(.fileURL) ?? false
        if !hasFileURL, let png = pngData(from: pb) {
            let hash = sha256Hex(png)
            if hash != lastHash {
                let savePath = saveDir + "/clipboard_\(formatter.string(from: Date())).png"
                do {
                    try png.write(to: URL(fileURLWithPath: savePath))
                    let ok = xattrValue.withUnsafeBytes {
                        setxattr(savePath, "com.apple.metadata:kMDItemIsScreenCapture",
                                 $0.baseAddress, xattrValue.count, 0, 0)
                    }
                    if ok != 0 {
                        FileHandle.standardError.write("Saved, but failed to set screenshot metadata: \(savePath)\n".data(using: .utf8)!)
                    } else {
                        let mdimport = Process()
                        mdimport.executableURL = URL(fileURLWithPath: "/usr/bin/mdimport")
                        mdimport.arguments = [savePath]
                        try? mdimport.run()
                    }
                    lastHash = hash
                    try? (hash + "\n").write(toFile: lastHashFile, atomically: true, encoding: .utf8)
                    print("Saved: \(savePath)")
                } catch {
                    FileHandle.standardError.write("Failed to save: \(error)\n".data(using: .utf8)!)
                }
            }
        }
    }
    usleep(200_000)
}
