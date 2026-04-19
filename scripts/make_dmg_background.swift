#!/usr/bin/env swift
// Generates a 640×400 DMG background PNG with:
//   • soft diagonal gradient
//   • subtle title at the top
//   • arrow between the app-icon slot (x≈160) and /Applications slot (x≈480)
//
// `create-dmg` lays the actual icons on top at those positions; the arrow
// just hints at the drag direction.

import AppKit
import CoreGraphics
import CoreText

let size = CGSize(width: 640, height: 400)
let ctx = CGContext(
    data: nil,
    width: Int(size.width),
    height: Int(size.height),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

let rect = CGRect(origin: .zero, size: size)

// Background gradient — neutral, slightly cool, so both the app icon and
// the /Applications link sit comfortably on top.
let bgColors = [
    CGColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0),
    CGColor(red: 0.90, green: 0.92, blue: 0.96, alpha: 1.0),
] as CFArray
let bgGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: bgColors,
    locations: [0.0, 1.0]
)!
ctx.drawLinearGradient(
    bgGradient,
    start: CGPoint(x: 0, y: size.height),
    end: CGPoint(x: size.width, y: 0),
    options: []
)

// Helper: draw text centred horizontally at a given distance from the
// top of the image (flips into bottom-origin CG coords internally).
func drawCenteredText(
    _ text: String,
    font: NSFont,
    color: NSColor,
    topOffset: CGFloat
) {
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    ctx.textPosition = CGPoint(
        x: (size.width - bounds.width) / 2 - bounds.origin.x,
        y: size.height - topOffset - bounds.height
    )
    CTLineDraw(line, ctx)
}

drawCenteredText(
    "KV-TabFinder",
    font: NSFont.systemFont(ofSize: 22, weight: .semibold),
    color: NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.30, alpha: 1.0),
    topOffset: 36
)
drawCenteredText(
    "Drag the app into Applications to install",
    font: NSFont.systemFont(ofSize: 12, weight: .regular),
    color: NSColor(calibratedRed: 0.40, green: 0.43, blue: 0.50, alpha: 1.0),
    topOffset: 72
)

// Arrow between the two icon slots. `create-dmg` positions icons at
// y=200 from the TOP of the window; in CG's bottom-origin coords
// that's y = 400 - 200 = 200. Earlier we miscalculated and the arrow
// floated above the icons.
let arrowColor = CGColor(red: 0.45, green: 0.48, blue: 0.56, alpha: 0.85)
ctx.setStrokeColor(arrowColor)
ctx.setFillColor(arrowColor)
ctx.setLineWidth(5)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

let arrowY: CGFloat = size.height - 200 // icon centre, from TOP → CG
let shaftStart = CGPoint(x: 248, y: arrowY)
let shaftEnd   = CGPoint(x: 372, y: arrowY)
ctx.move(to: shaftStart)
ctx.addLine(to: shaftEnd)
ctx.strokePath()

// Arrow head
let head = CGMutablePath()
head.move(to: CGPoint(x: 400, y: arrowY))
head.addLine(to: CGPoint(x: 372, y: arrowY - 16))
head.addLine(to: CGPoint(x: 372, y: arrowY + 16))
head.closeSubpath()
ctx.addPath(head)
ctx.fillPath()

// Save PNG.
let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let png = rep.representation(using: .png, properties: [:])!
let outURL = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "dmg_background.png")
try png.write(to: outURL)
print("wrote \(outURL.path)")
