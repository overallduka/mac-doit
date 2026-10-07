// Draws the app icon (build/icon.png, 1024px) from a green-screen frame. Run via: ./doit.sh icon
import AppKit

let size = 1024
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)  // macOS icon grid
let neon = CGColor(red: 0.1, green: 0.95, blue: 0.4, alpha: 1)
let deep = CGColor(red: 0.0, green: 0.35, blue: 0.2, alpha: 1)

func context(_ w: Int, _ h: Int) -> CGContext {
    CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

/// Removes the green screen (soft edge + despill).
func chromaKey(_ img: CGImage) -> CGImage {
    let w = img.width, h = img.height, ctx = context(w, h)
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    let p = ctx.data!.assumingMemoryBound(to: UInt8.self)
    for i in stride(from: 0, to: w * h * 4, by: 4) {
        let r = Double(p[i]), g = Double(p[i + 1]), b = Double(p[i + 2])
        let a = 1 - min(max((g - max(r, b) - 8) / 18, 0), 1)  // calibration: tweak 8/18 if green fringes remain
        p[i] = UInt8(r * a); p[i + 1] = UInt8(min(g, max(r, b)) * a); p[i + 2] = UInt8(b * a); p[i + 3] = UInt8(255 * a)
    }
    return ctx.makeImage()!
}

/// Same shape, solid white, hard edge (for the sticker outline).
func silhouette(_ img: CGImage) -> CGImage {
    let ctx = context(img.width, img.height)
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
    let p = ctx.data!.assumingMemoryBound(to: UInt8.self)
    for i in stride(from: 0, to: img.width * img.height * 4, by: 4) {
        let v: UInt8 = p[i + 3] > 90 ? 255 : 0
        p[i] = v; p[i + 1] = v; p[i + 2] = v; p[i + 3] = v
    }
    return ctx.makeImage()!
}

let frame = NSImage(contentsOfFile: "Tools/icon-source.png")!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let shia = chromaKey(frame.cropping(to: CGRect(x: 170, y: 15, width: 350, height: 275))!)  // arms up, mid-yell
let outline = silhouette(shia)

let ctx = context(size, size)
let squircle = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
let center = CGPoint(x: 512, y: 640)

// Tile + drop shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: CGColor(gray: 0, alpha: 0.45))
ctx.addPath(squircle); ctx.setFillColor(deep); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(squircle); ctx.clip()

// Neon radial glow + sunburst rays
let glow = CGGradient(colorsSpace: nil, colors: [neon, deep] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: 620, options: .drawsAfterEndLocation)
let rays = 20
for i in stride(from: 0, to: rays, by: 2) {
    let a0 = Double(i) / Double(rays) * 2 * .pi, a1 = Double(i + 1) / Double(rays) * 2 * .pi
    ctx.move(to: center)
    ctx.addArc(center: center, radius: 1000, startAngle: a0, endAngle: a1, clockwise: false)
    ctx.closePath()
}
ctx.setFillColor(CGColor(gray: 1, alpha: 0.13)); ctx.fillPath()

// Shia: sticker outline, then him, bottom-aligned so the crop is hidden by the tile edge
let shiaRect = CGRect(x: 40, y: 100, width: 980, height: 770)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.5))
for k in 0..<24 {
    let a = Double(k) / 24 * 2 * .pi
    ctx.draw(outline, in: shiaRect.offsetBy(dx: cos(a) * 14, dy: sin(a) * 14))
}
ctx.restoreGState()
ctx.interpolationQuality = .high
ctx.draw(shia, in: shiaRect)

// Bottom shade for the text
let shade = CGGradient(colorsSpace: nil, colors: [CGColor(gray: 0, alpha: 0.55), CGColor(gray: 0, alpha: 0)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(shade, start: CGPoint(x: 0, y: 100), end: CGPoint(x: 0, y: 420), options: [])

// Glossy top highlight
let gloss = CGGradient(colorsSpace: nil, colors: [CGColor(gray: 1, alpha: 0.18), CGColor(gray: 1, alpha: 0)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gloss, start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 700), options: [])

// "DO IT!" stamp: tilted, black stroke under a yellow fill
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
let font = NSFont.systemFont(ofSize: 210, weight: .black)
let text = "DO IT!"
let textSize = (text as NSString).size(withAttributes: [.font: font])
ctx.translateBy(x: 512, y: 250)
ctx.rotate(by: 8 * .pi / 180)
ctx.concatenate(CGAffineTransform(a: 1, b: 0, c: 0.18, d: 1, tx: 0, ty: 0))  // italic slant
let origin = NSPoint(x: -textSize.width / 2, y: -textSize.height / 2)
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 0, color: CGColor(gray: 0, alpha: 0.9))
(text as NSString).draw(at: origin, withAttributes: [.font: font, .strokeWidth: 22, .strokeColor: NSColor.black])
ctx.setShadow(offset: .zero, blur: 0, color: nil)
(text as NSString).draw(at: origin, withAttributes: [.font: font, .foregroundColor: NSColor(red: 1, green: 0.88, blue: 0.1, alpha: 1)])
ctx.restoreGState()

try! FileManager.default.createDirectory(atPath: "build", withIntermediateDirectories: true)
try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: "build/icon.png"))
print("build/icon.png")
