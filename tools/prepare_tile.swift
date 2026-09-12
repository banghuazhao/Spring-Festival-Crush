// Usage: swift tools/prepare_tile.swift input.png output.png
// Mechanical export only: preserve alpha, normalize padding, downsample for 3x tiles.
import AppKit
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else { fatalError("Expected input.png output.png") }
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Invalid source") }
let w = image.width, h = image.height
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
let bitmap = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                       space: space, bitmapInfo: info)!
bitmap.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
let bytes = bitmap.data!.assumingMemoryBound(to: UInt8.self)
var x0 = w, y0 = h, x1 = 0, y1 = 0
var transparent = 0
for y in 0..<h {
    for x in 0..<w {
        let alpha = bytes[(y * w + x) * 4 + 3]
        if alpha < 8 { transparent += 1 }
        if alpha > 16 {
            x0 = min(x0, x); x1 = max(x1, x)
            y0 = min(y0, y); y1 = max(y1, y)
        }
    }
}
guard transparent > w * h / 10, x1 > x0, y1 > y0 else { fatalError("Source must have real transparency") }
// Scan bounds use bitmap row order, as does the CGImage created from that bitmap.
let bounds = CGRect(x: max(0, x0 - 2), y: max(0, y0 - 2),
                    width: min(w - max(0, x0 - 2), x1 - x0 + 5),
                    height: min(h - max(0, y0 - 2), y1 - y0 + 5))
let cropped = bitmap.makeImage()!.cropping(to: bounds)!
let edge = 256
let target = CGContext(data: nil, width: edge, height: edge, bitsPerComponent: 8, bytesPerRow: edge * 4,
                       space: space, bitmapInfo: info)!
target.interpolationQuality = .high
let ratio = 220 / max(CGFloat(cropped.width), CGFloat(cropped.height))
let width = CGFloat(cropped.width) * ratio, height = CGFloat(cropped.height) * ratio
target.draw(cropped, in: CGRect(x: (256 - width) / 2, y: (256 - height) / 2, width: width, height: height))
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, target.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("PNG export failed") }
print("Exported \(output.lastPathComponent): 256px RGBA; source \(w)x\(h), transparent \(transparent * 100 / (w * h))%")
