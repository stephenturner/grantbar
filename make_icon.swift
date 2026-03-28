#!/usr/bin/env swift
// Generates AppIcon.iconset/ from the "newspaper.fill" SF Symbol.
// Run via: swift make_icon.swift
// Then: iconutil -c icns AppIcon.iconset

import AppKit
import CoreGraphics
import ImageIO

_ = NSApplication.shared  // required to init AppKit drawing subsystem

let iconsetDir = "AppIcon.iconset"
try! FileManager.default.createDirectory(
    atPath: iconsetDir,
    withIntermediateDirectories: true
)

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16",       16),
    ("icon_16x16@2x",    32),
    ("icon_32x32",       32),
    ("icon_32x32@2x",    64),
    ("icon_128x128",    128),
    ("icon_128x128@2x", 256),
    ("icon_256x256",    256),
    ("icon_256x256@2x", 512),
    ("icon_512x512",    512),
    ("icon_512x512@2x",1024),
]

for (name, pixels) in sizes {
    let s = CGFloat(pixels)

    // Off-screen RGBA bitmap context
    let ctx = CGContext(
        data: nil,
        width: pixels, height: pixels,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    // Wire AppKit drawing to this context
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx

    // Black rounded-rect background
    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    NSColor.black.setFill()
    NSBezierPath(roundedRect: rect, xRadius: s * 0.22, yRadius: s * 0.22).fill()

    // White newspaper symbol, centred with padding
    // pointSize drives the internal render resolution — set it to the symbol's
    // drawn size so AppKit rasterises sharp rather than upscaling a small glyph.
    let symRect = rect.insetBy(dx: s * 0.16, dy: s * 0.16)
    let symCfg  = NSImage.SymbolConfiguration(pointSize: symRect.width * 0.75, weight: .regular)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let sym = NSImage(systemSymbolName: "newspaper.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(symCfg)
    {
        sym.draw(in: symRect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    NSGraphicsContext.restoreGraphicsState()

    // Write PNG
    let dest = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: "\(iconsetDir)/\(name).png") as CFURL,
        "public.png" as CFString, 1, nil
    )!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)

    print("  \(name).png (\(pixels)px)")
}

print("Done → \(iconsetDir)/")
