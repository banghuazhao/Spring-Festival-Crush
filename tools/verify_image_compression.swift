// Usage: verify_image_compression original candidate
// Compare decoded sRGB pixels, dimensions, and alpha before accepting compression.
import Foundation
import ImageIO
import CoreGraphics

func decode(_ path: String) -> (Int, Int, [UInt8]) {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Invalid image: \(path)") }
    let w = image.width, h = image.height
    let bitmap = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                           space: CGColorSpace(name: CGColorSpace.sRGB)!,
                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    bitmap.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    return (w, h, Array(UnsafeBufferPointer(start: bitmap.data!.assumingMemoryBound(to: UInt8.self), count: w * h * 4)))
}
let a = decode(CommandLine.arguments[1]), b = decode(CommandLine.arguments[2])
guard a.0 == b.0, a.1 == b.1 else { exit(1) }
var squaredError = 0.0
var alphaError = 0
var changedOpacity = false
for i in stride(from: 0, to: a.2.count, by: 4) {
    for channel in 0..<3 {
        let difference = Double(a.2[i + channel]) - Double(b.2[i + channel])
        squaredError += difference * difference
    }
    alphaError = max(alphaError, abs(Int(a.2[i + 3]) - Int(b.2[i + 3])))
    if a.2[i + 3] == 255 && b.2[i + 3] != 255 { changedOpacity = true }
}
let mse = squaredError / Double(a.0 * a.1 * 3)
let psnr = mse == 0 ? 100 : 10 * log10(255 * 255 / mse)
print(String(format: "PSNR %.2f dB; max alpha error %d", psnr, alphaError))
guard psnr >= 34, alphaError <= 2, !changedOpacity else { exit(1) }
