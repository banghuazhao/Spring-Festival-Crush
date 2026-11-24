#!/usr/bin/env swift
// Draws the original Cloud Palace art: the Dragon tile and its board background.
//
//   swift tools/draw_dragon_art.swift
//
// Output goes straight into the asset catalog.
import AppKit
import CoreImage

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("SpringFestivalCrush/Assets.xcassets")

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

func canvas(_ width: Int, _ height: Int) -> CGContext {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Author in top-left coordinates, like the art itself is read.
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.interpolationQuality = .high
    return context
}

func gradient(_ stops: [(UInt32, CGFloat)]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
               colors: stops.map { color($0.0) } as CFArray, locations: stops.map(\.1))!
}

func fillLinear(_ c: CGContext, _ path: CGPath, _ stops: [(UInt32, CGFloat)], from: CGPoint, to: CGPoint) {
    c.saveGState(); c.addPath(path); c.clip()
    c.drawLinearGradient(gradient(stops), start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    c.restoreGState()
}

func fillRadial(_ c: CGContext, _ path: CGPath, _ stops: [(UInt32, CGFloat)], center: CGPoint, radius: CGFloat) {
    c.saveGState(); c.addPath(path); c.clip()
    c.drawRadialGradient(gradient(stops), startCenter: center, startRadius: 0, endCenter: center, endRadius: radius,
                         options: [.drawsAfterEndLocation])
    c.restoreGState()
}

func ellipse(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2), transform: nil)
}

/// Mirrors a path across the tile's vertical center line.
func mirrored(_ path: CGPath, width: CGFloat) -> CGPath {
    var transform = CGAffineTransform(translationX: width, y: 0).scaledBy(x: -1, y: 1)
    return path.copy(using: &transform)!
}

func path(_ build: (CGMutablePath) -> Void) -> CGPath {
    let result = CGMutablePath()
    build(result)
    return result
}

func writePNG(_ image: CGImage, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

func writeJPEG(_ image: CGImage, to url: URL, quality: CGFloat) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    try rep.representation(using: .jpeg, properties: [.compressionFactor: quality])!.write(to: url)
}

func resampled(_ image: CGImage, width: Int, height: Int) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

// MARK: - Dragon tile

func drawDragonTile() -> CGImage {
    let scale: CGFloat = 4
    let c = canvas(1024, 1024)
    c.scaleBy(x: scale, y: scale)
    let w: CGFloat = 256

    func both(_ shape: CGPath, draw: (CGPath) -> Void) {
        draw(shape)
        draw(mirrored(shape, width: w))
    }

    // Mane behind the head.
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: 3), blur: 6, color: color(0x3B1020, 0.35))
    for (x, y, rx, ry, angle) in [(58.0, 118.0, 19.0, 34.0, -0.72), (42.0, 150.0, 18.0, 31.0, -1.1),
                                  (50.0, 184.0, 17.0, 28.0, -1.75), (74.0, 208.0, 15.0, 22.0, -2.25)] as [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] {
        var rotate = CGAffineTransform(translationX: x, y: y).rotated(by: angle)
        let tuft = CGPath(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2), transform: &rotate)
        both(tuft) { fillRadial(c, $0, [(0xFF8A5C, 0), (0xE23E3B, 0.6), (0xA81F36, 1)],
                                center: CGPoint(x: $0.boundingBox.midX, y: $0.boundingBox.minY + 6), radius: 58) }
    }
    c.restoreGState()

    // Antlers.
    let antler = path { p in
        p.move(to: CGPoint(x: 101, y: 72))
        p.addCurve(to: CGPoint(x: 62, y: 12), control1: CGPoint(x: 86, y: 52), control2: CGPoint(x: 72, y: 34))
        p.addCurve(to: CGPoint(x: 83, y: 25), control1: CGPoint(x: 71, y: 12), control2: CGPoint(x: 78, y: 17))
        p.addCurve(to: CGPoint(x: 88, y: 10), control1: CGPoint(x: 85, y: 20), control2: CGPoint(x: 85, y: 14))
        p.addCurve(to: CGPoint(x: 98, y: 44), control1: CGPoint(x: 100, y: 19), control2: CGPoint(x: 101, y: 32))
        p.addCurve(to: CGPoint(x: 119, y: 66), control1: CGPoint(x: 105, y: 51), control2: CGPoint(x: 112, y: 59))
        p.closeSubpath()
    }
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: 2), blur: 3, color: color(0x6B3E05, 0.5))
    both(antler) { fillLinear(c, $0, [(0xFFF1A8, 0), (0xF4BE3A, 0.55), (0xBC7812, 1)],
                              from: CGPoint(x: 0, y: 8), to: CGPoint(x: 0, y: 78)) }
    c.restoreGState()

    // Fin ears.
    let ear = path { p in
        p.move(to: CGPoint(x: 62, y: 112))
        p.addCurve(to: CGPoint(x: 12, y: 86), control1: CGPoint(x: 45, y: 106), control2: CGPoint(x: 26, y: 100))
        p.addCurve(to: CGPoint(x: 30, y: 128), control1: CGPoint(x: 13, y: 103), control2: CGPoint(x: 18, y: 118))
        p.addCurve(to: CGPoint(x: 65, y: 143), control1: CGPoint(x: 41, y: 138), control2: CGPoint(x: 53, y: 142))
        p.closeSubpath()
    }
    both(ear) { fillLinear(c, $0, [(0x7BE2C8, 0), (0x24A08F, 0.6), (0x116A69, 1)],
                           from: CGPoint(x: 0, y: 84), to: CGPoint(x: 0, y: 145)) }

    // Head.
    let head = path { p in
        p.move(to: CGPoint(x: 128, y: 48))
        p.addCurve(to: CGPoint(x: 205, y: 118), control1: CGPoint(x: 174, y: 48), control2: CGPoint(x: 203, y: 78))
        p.addCurve(to: CGPoint(x: 190, y: 184), control1: CGPoint(x: 207, y: 145), control2: CGPoint(x: 203, y: 168))
        p.addCurve(to: CGPoint(x: 128, y: 230), control1: CGPoint(x: 178, y: 212), control2: CGPoint(x: 156, y: 230))
        p.addCurve(to: CGPoint(x: 66, y: 184), control1: CGPoint(x: 100, y: 230), control2: CGPoint(x: 78, y: 212))
        p.addCurve(to: CGPoint(x: 51, y: 118), control1: CGPoint(x: 53, y: 168), control2: CGPoint(x: 49, y: 145))
        p.addCurve(to: CGPoint(x: 128, y: 48), control1: CGPoint(x: 53, y: 78), control2: CGPoint(x: 82, y: 48))
        p.closeSubpath()
    }
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: 4), blur: 7, color: color(0x062F33, 0.45))
    c.addPath(head); c.setFillColor(color(0x1B8C80)); c.fillPath()
    c.restoreGState()
    fillRadial(c, head, [(0xA8F2DC, 0), (0x48C8AE, 0.42), (0x1B8F85, 0.78), (0x0E6467, 1)],
               center: CGPoint(x: 112, y: 84), radius: 176)

    // Forehead scales, clipped to the head.
    c.saveGState(); c.addPath(head); c.clip()
    c.setLineWidth(2)
    c.setStrokeColor(color(0xE6FFF6, 0.4))
    for row in 0 ..< 3 {
        let y = 62 + CGFloat(row) * 12
        let count = 3 + row
        for index in 0 ..< count {
            let x = 128 + (CGFloat(index) - CGFloat(count - 1) / 2) * 21
            c.addArc(center: CGPoint(x: x, y: y), radius: 10.5, startAngle: 0.25, endAngle: .pi - 0.25, clockwise: false)
            c.strokePath()
        }
    }
    c.restoreGState()

    // Gold forehead pearl.
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: 1.5), blur: 3, color: color(0x6B3E05, 0.6))
    fillRadial(c, ellipse(128, 89, 9.5, 9.5), [(0xFFFBE0, 0), (0xFFD65A, 0.55), (0xC47F12, 1)],
               center: CGPoint(x: 125, y: 85), radius: 13)
    c.restoreGState()

    // Brows.
    let brow = path { p in
        p.move(to: CGPoint(x: 72, y: 109))
        p.addCurve(to: CGPoint(x: 112, y: 104), control1: CGPoint(x: 83, y: 97), control2: CGPoint(x: 100, y: 96))
    }
    c.setLineWidth(6)
    c.setStrokeColor(color(0xF8C94B))
    both(brow) { c.addPath($0); c.strokePath() }

    // Eyes.
    for x in [93.0, 163.0] as [CGFloat] {
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: 1.5), blur: 2.5, color: color(0x062F33, 0.5))
        c.addPath(ellipse(x, 133, 20, 22)); c.setFillColor(color(0xFFFDF4)); c.fillPath()
        c.restoreGState()
        fillRadial(c, ellipse(x, 135, 15.5, 18), [(0xC97B32, 0), (0x7A3D16, 0.55), (0x30160A, 1)],
                   center: CGPoint(x: x, y: 145), radius: 22)
        c.addPath(ellipse(x, 135, 8.5, 10.5)); c.setFillColor(color(0x140A07)); c.fillPath()
        c.addPath(ellipse(x - 5, 127, 5.5, 6)); c.setFillColor(color(0xFFFFFF)); c.fillPath()
        c.addPath(ellipse(x + 5.5, 143, 2.6, 2.6)); c.setFillColor(color(0xFFFFFF, 0.9)); c.fillPath()
    }

    // Blush.
    c.saveGState()
    c.setBlendMode(.normal)
    for x in [66.0, 190.0] as [CGFloat] {
        c.saveGState()
        c.addPath(ellipse(x, 165, 19, 12)); c.clip()
        c.drawRadialGradient(CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                        colors: [color(0xFF7E8E, 0.75), color(0xFF7E8E, 0)] as CFArray,
                                        locations: [0, 1])!,
                             startCenter: CGPoint(x: x, y: 165), startRadius: 0,
                             endCenter: CGPoint(x: x, y: 165), endRadius: 19, options: [])
        c.restoreGState()
    }
    c.restoreGState()

    // Muzzle.
    let muzzle = path { p in
        p.move(to: CGPoint(x: 128, y: 152))
        p.addCurve(to: CGPoint(x: 178, y: 190), control1: CGPoint(x: 158, y: 152), control2: CGPoint(x: 180, y: 167))
        p.addCurve(to: CGPoint(x: 128, y: 224), control1: CGPoint(x: 176, y: 212), control2: CGPoint(x: 153, y: 224))
        p.addCurve(to: CGPoint(x: 78, y: 190), control1: CGPoint(x: 103, y: 224), control2: CGPoint(x: 80, y: 212))
        p.addCurve(to: CGPoint(x: 128, y: 152), control1: CGPoint(x: 76, y: 167), control2: CGPoint(x: 98, y: 152))
        p.closeSubpath()
    }
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: color(0x062F33, 0.35))
    c.addPath(muzzle); c.setFillColor(color(0xFFF0CC)); c.fillPath()
    c.restoreGState()
    fillRadial(c, muzzle, [(0xFFFDF2, 0), (0xFFEFC6, 0.62), (0xE9C487, 1)],
               center: CGPoint(x: 124, y: 172), radius: 66)

    // Nostrils.
    for x in [113.0, 143.0] as [CGFloat] {
        c.addPath(ellipse(x, 176, 4.4, 3.2)); c.setFillColor(color(0x7E4E2B)); c.fillPath()
    }

    // Smile and tongue.
    let mouth = path { p in
        p.move(to: CGPoint(x: 104, y: 194))
        p.addCurve(to: CGPoint(x: 152, y: 194), control1: CGPoint(x: 112, y: 203), control2: CGPoint(x: 144, y: 203))
        p.addCurve(to: CGPoint(x: 128, y: 215), control1: CGPoint(x: 149, y: 209), control2: CGPoint(x: 139, y: 215))
        p.addCurve(to: CGPoint(x: 104, y: 194), control1: CGPoint(x: 117, y: 215), control2: CGPoint(x: 107, y: 209))
        p.closeSubpath()
    }
    c.addPath(mouth); c.setFillColor(color(0x8E2334)); c.fillPath()
    c.saveGState(); c.addPath(mouth); c.clip()
    c.addPath(ellipse(128, 215, 15, 10)); c.setFillColor(color(0xFF7D8D)); c.fillPath()
    c.restoreGState()
    let fang = path { p in
        p.move(to: CGPoint(x: 111, y: 198))
        p.addLine(to: CGPoint(x: 119, y: 200))
        p.addLine(to: CGPoint(x: 114, y: 207))
        p.closeSubpath()
    }
    both(fang) { c.addPath($0); c.setFillColor(color(0xFFFFFF)); c.fillPath() }

    // Whiskers.
    let whisker = path { p in
        p.move(to: CGPoint(x: 86, y: 184))
        p.addCurve(to: CGPoint(x: 18, y: 190), control1: CGPoint(x: 62, y: 176), control2: CGPoint(x: 34, y: 170))
        p.addCurve(to: CGPoint(x: 32, y: 212), control1: CGPoint(x: 10, y: 200), control2: CGPoint(x: 19, y: 213))
    }
    c.setLineWidth(4.5)
    c.setStrokeColor(color(0xB77512))
    both(whisker) { c.addPath($0); c.strokePath() }
    c.setLineWidth(2.4)
    c.setStrokeColor(color(0xFFE28A))
    both(whisker) { c.addPath($0); c.strokePath() }

    return resampled(c.makeImage()!, width: 256, height: 256)
}

// MARK: - Board background

func softLayer(width: Int, height: Int, blur: Double, draw: (CGContext) -> Void) -> CGImage {
    let layer = canvas(width, height)
    draw(layer)
    let input = CIImage(cgImage: layer.makeImage()!)
    let output = input.clampedToExtent().applyingGaussianBlur(sigma: blur).cropped(to: input.extent)
    return CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
        .createCGImage(output, from: input.extent)!
}

func place(_ image: CGImage, on c: CGContext, width: CGFloat, height: CGFloat, alpha: CGFloat = 1) {
    c.saveGState()
    c.translateBy(x: 0, y: height)
    c.scaleBy(x: 1, y: -1)
    c.setAlpha(alpha)
    c.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    c.restoreGState()
}

/// A stable pseudo-random stream, so re-running the script reproduces the same art.
struct Stream {
    var seed: UInt64
    mutating func next(_ low: CGFloat, _ high: CGFloat) -> CGFloat {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        let fraction = CGFloat((seed >> 33) % 100_000) / 100_000
        return low + (high - low) * fraction
    }
}

func cloudBank(_ c: CGContext, y: CGFloat, width: CGFloat, thickness: CGFloat, tint: UInt32, alpha: CGFloat, rng: inout Stream) {
    c.setFillColor(color(tint, alpha))
    var x: CGFloat = -60
    while x < width + 60 {
        let radius = rng.next(thickness * 0.55, thickness * 1.25)
        c.addPath(ellipse(x, y + rng.next(-thickness * 0.3, thickness * 0.3), radius * 1.6, radius))
        c.fillPath()
        x += radius * rng.next(0.9, 1.5)
    }
    c.fill(CGRect(x: 0, y: y, width: width, height: thickness * 1.2))
}

func pagoda(_ c: CGContext, x: CGFloat, base: CGFloat, size: CGFloat, roof: UInt32, wall: UInt32, glow: UInt32) {
    for tier in 0 ..< 3 {
        let t = CGFloat(tier)
        let tierBase = base - t * size * 0.46
        let half = size * (0.56 - t * 0.12)
        c.setFillColor(color(wall))
        c.fill(CGRect(x: x - half * 0.68, y: tierBase - size * 0.3, width: half * 1.36, height: size * 0.3))
        c.setFillColor(color(glow, 0.95))
        for window in -1 ... 1 {
            c.fill(CGRect(x: x + CGFloat(window) * half * 0.38 - size * 0.035, y: tierBase - size * 0.24,
                          width: size * 0.07, height: size * 0.16))
        }
        let eave = path { p in
            p.move(to: CGPoint(x: x - half * 1.28, y: tierBase - size * 0.3))
            p.addQuadCurve(to: CGPoint(x: x - half * 0.3, y: tierBase - size * 0.53),
                           control: CGPoint(x: x - half * 0.8, y: tierBase - size * 0.32))
            p.addLine(to: CGPoint(x: x + half * 0.3, y: tierBase - size * 0.53))
            p.addQuadCurve(to: CGPoint(x: x + half * 1.28, y: tierBase - size * 0.3),
                           control: CGPoint(x: x + half * 0.8, y: tierBase - size * 0.32))
            p.addQuadCurve(to: CGPoint(x: x - half * 1.28, y: tierBase - size * 0.3),
                           control: CGPoint(x: x, y: tierBase - size * 0.2))
            p.closeSubpath()
        }
        c.addPath(eave); c.setFillColor(color(roof)); c.fillPath()
    }
    c.setFillColor(color(0xF7CE63))
    c.fill(CGRect(x: x - size * 0.02, y: base - size * 1.62, width: size * 0.04, height: size * 0.32))
    c.addPath(ellipse(x, base - size * 1.63, size * 0.05, size * 0.05)); c.fillPath()
}

func drawBackground() -> CGImage {
    let width = 887, height = 1774
    let w = CGFloat(width), h = CGFloat(height)
    let c = canvas(width, height)

    // Sky: morning blue into the pale mist the board sits on.
    c.drawLinearGradient(gradient([(0x4F78B4, 0), (0x86AAD6, 0.16), (0xBCD3EA, 0.36), (0xDCE7F3, 0.58),
                                   (0xC9D9EC, 0.8), (0x8FA9CD, 1)]),
                         start: .zero, end: CGPoint(x: 0, y: h), options: [])

    // Sun halo behind the palace.
    let halo = CGPoint(x: w * 0.74, y: h * 0.105)
    c.drawRadialGradient(CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                    colors: [color(0xFFFBEA, 0.95), color(0xFFFFFF, 0.34), color(0xFFFFFF, 0)] as CFArray,
                                    locations: [0, 0.34, 1])!,
                         startCenter: halo, startRadius: 0, endCenter: halo, endRadius: w * 0.62, options: [])
    c.addPath(ellipse(halo.x, halo.y, 82, 82)); c.setFillColor(color(0xFFF9E6, 0.96)); c.fillPath()

    var rng = Stream(seed: 20_260_124)

    // Far peaks.
    place(softLayer(width: width, height: height, blur: 7) { layer in
        layer.setFillColor(color(0x6F92C3, 0.72))
        for (x, y, rx, ry) in [(120.0, 395.0, 220.0, 150.0), (390.0, 410.0, 190.0, 98.0), (760.0, 395.0, 230.0, 142.0)]
            as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            layer.addPath(ellipse(x, y, rx, ry)); layer.fillPath()
        }
    }, on: c, width: w, height: h)

    // Far clouds.
    place(softLayer(width: width, height: height, blur: 12) { layer in
        cloudBank(layer, y: 372, width: w, thickness: 48, tint: 0xEFF5FB, alpha: 0.92, rng: &rng)
    }, on: c, width: w, height: h)

    // Floating palace island.
    let island = path { p in
        p.move(to: CGPoint(x: 470, y: 322))
        p.addCurve(to: CGPoint(x: 900, y: 300), control1: CGPoint(x: 590, y: 300), control2: CGPoint(x: 760, y: 296))
        p.addLine(to: CGPoint(x: 900, y: 372))
        p.addCurve(to: CGPoint(x: 610, y: 438), control1: CGPoint(x: 820, y: 430), control2: CGPoint(x: 700, y: 452))
        p.addCurve(to: CGPoint(x: 470, y: 322), control1: CGPoint(x: 540, y: 420), control2: CGPoint(x: 490, y: 372))
        p.closeSubpath()
    }
    fillLinear(c, island, [(0x7D93B6, 0), (0x56698F, 1)], from: CGPoint(x: 0, y: 298), to: CGPoint(x: 0, y: 445))
    pagoda(c, x: 696, base: 312, size: 106, roof: 0x315A8E, wall: 0xB7473F, glow: 0xFFE39A)
    pagoda(c, x: 556, base: 322, size: 54, roof: 0x3C659A, wall: 0xB9524A, glow: 0xFFE39A)

    // Mist through the island and the calm middle of the board.
    place(softLayer(width: width, height: height, blur: 22) { layer in
        cloudBank(layer, y: 442, width: w, thickness: 58, tint: 0xF5F9FD, alpha: 0.98, rng: &rng)
        layer.setFillColor(color(0xEAF1F8, 0.82))
        layer.fill(CGRect(x: 0, y: 520, width: w, height: 760))
    }, on: c, width: w, height: h)

    // Soft gold bands, so the middle is not flat behind the board.
    place(softLayer(width: width, height: height, blur: 34) { layer in
        for (y, tint, alpha) in [(650.0, 0xFFF0CC, 0.5), (900.0, 0xD3E2F3, 0.75), (1150.0, 0xFFF2D6, 0.42)]
            as [(CGFloat, UInt32, CGFloat)] {
            layer.setFillColor(color(tint, alpha))
            layer.addPath(ellipse(w * 0.5, y, w * 0.72, 62)); layer.fillPath()
        }
    }, on: c, width: w, height: h)

    // Foreground clouds.
    place(softLayer(width: width, height: height, blur: 9) { layer in
        cloudBank(layer, y: 1400, width: w, thickness: 46, tint: 0xB5C9E2, alpha: 0.85, rng: &rng)
    }, on: c, width: w, height: h)

    // Stone terrace.
    let terrace = path { p in
        p.move(to: CGPoint(x: 0, y: 1560))
        p.addCurve(to: CGPoint(x: w, y: 1560), control1: CGPoint(x: w * 0.32, y: 1520), control2: CGPoint(x: w * 0.68, y: 1520))
        p.addLine(to: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.closeSubpath()
    }
    fillLinear(c, terrace, [(0xAEBBD2, 0), (0x7485A6, 0.6), (0x54658A, 1)],
               from: CGPoint(x: 0, y: 1525), to: CGPoint(x: 0, y: h))
    c.saveGState(); c.addPath(terrace); c.clip()
    c.setStrokeColor(color(0xE6EEF8, 0.28)); c.setLineWidth(2)
    for row in 0 ..< 5 {
        let y = 1590 + CGFloat(row) * CGFloat(row + 3) * 7
        c.move(to: CGPoint(x: 0, y: y)); c.addLine(to: CGPoint(x: w, y: y)); c.strokePath()
        var x: CGFloat = row.isMultiple(of: 2) ? 30 : 110
        while x < w {
            c.move(to: CGPoint(x: x, y: y)); c.addLine(to: CGPoint(x: x + (x - w / 2) * 0.1, y: y + 30)); c.strokePath()
            x += 165
        }
    }
    c.restoreGState()

    // Balustrade pillars with gold finials on both edges.
    for side in [false, true] {
        let x = side ? w - 76 : 76
        let body = CGRect(x: x - 40, y: 1408, width: 80, height: 196)
        let pillar = CGPath(roundedRect: body, cornerWidth: 6, cornerHeight: 6, transform: nil)
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: 8), blur: 14, color: color(0x22304F, 0.45))
        c.addPath(pillar); c.setFillColor(color(0x8FA0BE)); c.fillPath()
        c.restoreGState()
        fillLinear(c, pillar, [(0xD4DDEB, 0), (0x8FA0BE, 0.6), (0x6A7C9E, 1)],
                   from: CGPoint(x: x - 40, y: 0), to: CGPoint(x: x + 40, y: 0))
        c.setStrokeColor(color(0x4F6288, 0.65)); c.setLineWidth(3)
        c.stroke(body.insetBy(dx: 12, dy: 18))
        fillRadial(c, ellipse(x, 1386, 30, 30), [(0xFFF6CF, 0), (0xF2BF47, 0.6), (0xA96D0E, 1)],
                   center: CGPoint(x: x - 8, y: 1376), radius: 44)
        c.setFillColor(color(0xA9B6CD))
        c.fill(CGRect(x: x - 48, y: 1404, width: 96, height: 12))
        let rail = CGRect(x: side ? x - 190 : x + 40, y: 1490, width: 150, height: 16)
        c.setFillColor(color(0xA3B1CA)); c.fill(rail)
        for post in 0 ..< 3 {
            let px = rail.minX + 22 + CGFloat(post) * 50
            c.setFillColor(color(0x8596B5))
            c.fill(CGRect(x: px, y: 1506, width: 13, height: 58))
        }
    }

    // Near mist laps over the terrace edge.
    place(softLayer(width: width, height: height, blur: 18) { layer in
        cloudBank(layer, y: 1628, width: w, thickness: 34, tint: 0xE9F0F8, alpha: 0.5, rng: &rng)
        layer.clear(CGRect(x: 0, y: 1680, width: w, height: h - 1680))
    }, on: c, width: w, height: h)

    return c.makeImage()!
}

// MARK: - Output

func contents(_ filename: String, scaled: Bool) -> String {
    scaled
        ? "{\n  \"images\": [\n    {\"filename\": \"\(filename)\", \"idiom\": \"universal\", \"scale\": \"1x\"},\n    {\"idiom\": \"universal\", \"scale\": \"2x\"},\n    {\"idiom\": \"universal\", \"scale\": \"3x\"}\n  ],\n  \"info\": {\"author\": \"xcode\", \"version\": 1}\n}\n"
        : "{\n  \"images\": [{\"filename\": \"\(filename)\", \"idiom\": \"universal\"}],\n  \"info\": {\"author\": \"xcode\", \"version\": 1}\n}\n"
}

let tileSet = assets.appendingPathComponent("Sprites/DragonTile.imageset")
let backgroundSet = assets.appendingPathComponent("Background/DragonBoardBackground.imageset")
try FileManager.default.createDirectory(at: tileSet, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: backgroundSet, withIntermediateDirectories: true)
try writePNG(drawDragonTile(), to: tileSet.appendingPathComponent("DragonTile.png"))
try writeJPEG(drawBackground(), to: backgroundSet.appendingPathComponent("DragonBoardBackground.jpg"), quality: 0.82)
try contents("DragonTile.png", scaled: false).write(to: tileSet.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
try contents("DragonBoardBackground.jpg", scaled: true).write(to: backgroundSet.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("Dragon art written")
