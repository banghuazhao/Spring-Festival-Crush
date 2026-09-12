// Usage: swift tools/audit_images.swift <app directory>
// Read-only inventory of raster images, including decoded alpha rather than metadata alone.
import Foundation
import ImageIO
import CoreGraphics

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let paths = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey])!
var rows = [[String: Any]]()
for case let url as URL in paths where ["png", "jpg", "jpeg"].contains(url.pathExtension.lowercased()) {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fatalError("Cannot decode \(url.path)")
    }
    let width = image.width, height = image.height
    let bitmap = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                           bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    bitmap.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    let bytes = bitmap.data!.assumingMemoryBound(to: UInt8.self)
    let transparent = stride(from: 3, to: width * height * 4, by: 4).contains { bytes[$0] < 255 }
    rows.append(["path": url.path, "bytes": try url.resourceValues(forKeys: [.fileSizeKey]).fileSize!,
                 "width": width, "height": height, "transparent": transparent])
}
rows.sort { ($0["bytes"] as! Int) > ($1["bytes"] as! Int) }
let data = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
print(String(decoding: data, as: UTF8.self))
