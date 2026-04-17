#!/usr/bin/env swift
// Generates a 1024×1024 PNG master icon for KV-TabFinder.
// Design: rounded-square violet→indigo gradient with a stylised
// magnifying glass + "KV" monogram.

import AppKit
import CoreGraphics
import CoreText

let size = CGSize(width: 1024, height: 1024)
let cornerRadius: CGFloat = 224 // matches macOS Big Sur+ icon mask proportion

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

// Rounded background
let bgPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
ctx.addPath(bgPath)
ctx.clip()

// Gradient
let colors = [
    CGColor(red: 0.36, green: 0.28, blue: 0.82, alpha: 1.0), // indigo
    CGColor(red: 0.58, green: 0.35, blue: 0.88, alpha: 1.0), // violet
] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0])!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: size.height),
    end: CGPoint(x: size.width, y: 0),
    options: []
)

// Magnifying glass — ring
let centerX: CGFloat = 420
let centerY: CGFloat = 600
let ringRadius: CGFloat = 230
let ringLineWidth: CGFloat = 58

ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.96))
ctx.setLineWidth(ringLineWidth)
ctx.setLineCap(.round)
ctx.strokeEllipse(in: CGRect(
    x: centerX - ringRadius,
    y: centerY - ringRadius,
    width: ringRadius * 2,
    height: ringRadius * 2
))

// Magnifying glass — handle
ctx.setLineWidth(ringLineWidth)
ctx.setLineCap(.round)
let angle: CGFloat = -.pi / 4
let handleStart = CGPoint(
    x: centerX + cos(angle) * ringRadius,
    y: centerY + sin(angle) * ringRadius
)
let handleEnd = CGPoint(
    x: handleStart.x + 230,
    y: handleStart.y - 230
)
ctx.move(to: handleStart)
ctx.addLine(to: handleEnd)
ctx.strokePath()

// "KV" text inside the ring
let text = "KV"
let font = NSFont.systemFont(ofSize: 260, weight: .heavy)
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 1.0),
]

let attrStr = NSAttributedString(string: text, attributes: attrs)
let line = CTLineCreateWithAttributedString(attrStr)
let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

ctx.textMatrix = .identity
let textX = centerX - bounds.width / 2 - bounds.origin.x
let textY = centerY - bounds.height / 2 - bounds.origin.y
ctx.textPosition = CGPoint(x: textX, y: textY)
CTLineDraw(line, ctx)

// Save PNG
let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let png = rep.representation(using: .png, properties: [:])!

let outputURL = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon_master.png")

try png.write(to: outputURL)
print("wrote \(outputURL.path)")
