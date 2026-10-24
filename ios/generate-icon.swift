import AppKit
import Foundation

// Code-drawn artwork keeps the app icon reproducible without design services.
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
let bounds = NSRect(origin: .zero, size: size)
let gradient = NSGradient(starting: NSColor(srgbRed: 0.26, green: 0.20, blue: 0.59, alpha: 1),
                          ending: NSColor(srgbRed: 0.045, green: 0.065, blue: 0.13, alpha: 1))!
gradient.draw(in: bounds, angle: -70)
let mark = NSBezierPath()
let points: [NSPoint] = [.init(x: 220, y: 740), .init(x: 385, y: 740), .init(x: 512, y: 408),
                        .init(x: 639, y: 740), .init(x: 804, y: 740), .init(x: 594, y: 240), .init(x: 430, y: 240)]
mark.move(to: points[0])
for point in points.dropFirst() { mark.line(to: point) }
mark.close()
NSColor.white.setFill()
mark.fill()
let play = NSBezierPath()
play.move(to: .init(x: 700, y: 245))
play.line(to: .init(x: 700, y: 405))
play.line(to: .init(x: 835, y: 325))
play.close()
NSColor(srgbRed: 0.38, green: 0.91, blue: 0.79, alpha: 1).setFill()
play.fill()
image.unlockFocus()

let root = URL(fileURLWithPath: "ios/VIU/Assets.xcassets", isDirectory: true)
let icon = root.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: icon, withIntermediateDirectories: true)
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
let rgb = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
                          bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false,
                          isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rgb)
bitmap.draw(in: bounds)
NSGraphicsContext.restoreGraphicsState()
try rgb.representation(using: .png, properties: [:])!.write(to: icon.appendingPathComponent("AppIcon.png"))
let contents = """
{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
"""
try Data(contents.utf8).write(to: icon.appendingPathComponent("Contents.json"))
try Data("{\"info\":{\"author\":\"xcode\",\"version\":1}}".utf8).write(to: root.appendingPathComponent("Contents.json"))
