import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Render directly into an opaque bitmap; no window server is required.
let size = 1024
let space = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: size * 4, space: space,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let colors = [CGColor(red: 0.26, green: 0.20, blue: 0.59, alpha: 1),
              CGColor(red: 0.045, green: 0.065, blue: 0.13, alpha: 1)] as CFArray
let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 900, y: 0),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
let points: [CGPoint] = [.init(x: 220, y: 740), .init(x: 385, y: 740), .init(x: 512, y: 408),
                         .init(x: 639, y: 740), .init(x: 804, y: 740), .init(x: 594, y: 240), .init(x: 430, y: 240)]
context.addLines(between: points)
context.closePath()
context.setFillColor(CGColor(gray: 1, alpha: 1))
context.fillPath()
context.addLines(between: [.init(x: 700, y: 245), .init(x: 700, y: 405), .init(x: 835, y: 325)])
context.closePath()
context.setFillColor(CGColor(red: 0.38, green: 0.91, blue: 0.79, alpha: 1))
context.fillPath()
let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
let whitePixels = stride(from: 0, to: size * size * 4, by: 4).filter {
    pixels[$0] > 240 && pixels[$0 + 1] > 240 && pixels[$0 + 2] > 240
}.count
precondition(whitePixels > 50_000, "App icon rendering failed: missing white monogram")
let root = URL(fileURLWithPath: "ios/VIU/Assets.xcassets", isDirectory: true)
let icon = root.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: icon, withIntermediateDirectories: true)
let destination = CGImageDestinationCreateWithURL(icon.appendingPathComponent("AppIcon.png") as CFURL,
                                                 UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination), "Couldn't write app icon")
let contents = """
{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
"""
try Data(contents.utf8).write(to: icon.appendingPathComponent("Contents.json"))
try Data("{\"info\":{\"author\":\"xcode\",\"version\":1}}".utf8).write(to: root.appendingPathComponent("Contents.json"))
