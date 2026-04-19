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

// Title "KV-TabFinder" near the top.
let title = "KV-TabFinder"
let titleFont = NSFont.systemFont(ofSize: 24, weight: .semibold)
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.30, alpha: 1.0),
]
let titleStr = NSAttributedString(string: title, attributes: titleAttrs)
let titleLine = CTLineCreateWithAttributedString(titleStr)
let titleBounds = CTLineGetBoundsWithOptions(titleLine, .useOpticalBounds)
ctx.textPosition = CGPoint(
    x: (size.width - titleBounds.width) / 2 - titleBounds.origin.x,
    y: size.height - 60
)
CTLineDraw(titleLine, ctx)

// Sub-title / hint.
let hint = "Drag the app into Applications to install"
let hintFont = NSFont.systemFont(ofSize: 12, weight: .regular)
let hintAttrs: [NSAttributedString.Key: Any] = [
    .font: hintFont,
    .foregroundColor: NSColor(calibratedRed: 0.40, green: 0.43, blue: 0.50, alpha: 1.0),
]
let hintStr = NSAttributedString(string: hint, attributes: hintAttrs)
let hintLine = CTLineCreateWithAttributedString(hintStr)
let hintBounds = CTLineGetBoundsWithOptions(hintLine, .useOpticalBounds)
ctx.textPosition = CGPoint(
    x: (size.width - hintBounds.width) / 2 - hintBounds.origin.x,
    y: size.height - 90
)
CTLineDraw(hintLine, ctx)

// Arrow between the two icon slots. create-dmg default icon-y in our
// script is 200 (from bottom), icons are sized ~128. Arrow sits
// centred vertically with them.
let arrowColor = CGColor(red: 0.45, green: 0.48, blue: 0.56, alpha: 0.75)
ctx.setStrokeColor(arrowColor)
ctx.setFillColor(arrowColor)
ctx.setLineWidth(4)
ctx.setLineCap(.round)

// Shaft
let arrowY: CGFloat = 200 + 64 // vertical midline of a 128-pt icon at y=200
let shaftStart = CGPoint(x: 250, y: arrowY)
let shaftEnd   = CGPoint(x: 380, y: arrowY)
ctx.move(to: shaftStart)
ctx.addLine(to: shaftEnd)
ctx.strokePath()

// Arrow head
let head = CGMutablePath()
head.move(to: CGPoint(x: 400, y: arrowY))
head.addLine(to: CGPoint(x: 380, y: arrowY - 12))
head.addLine(to: CGPoint(x: 380, y: arrowY + 12))
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
