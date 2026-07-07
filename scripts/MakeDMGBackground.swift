import AppKit

guard CommandLine.arguments.count == 2 else {
    fatalError("usage: MakeDMGBackground.swift /path/to/background.png")
}

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 640, height: 380)
let image = NSImage(size: size)

image.lockFocus()

NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.13, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()

let panelRect = NSRect(x: 34, y: 34, width: 572, height: 312)
let panel = NSBezierPath(roundedRect: panelRect, xRadius: 18, yRadius: 18)
NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.96, alpha: 1).setFill()
panel.fill()

NSColor(calibratedRed: 0.14, green: 0.18, blue: 0.22, alpha: 1).setStroke()
panel.lineWidth = 1
panel.stroke()

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 30, weight: .bold),
    .foregroundColor: NSColor(calibratedRed: 0.09, green: 0.11, blue: 0.14, alpha: 1)
]
"MeowVault".draw(at: NSPoint(x: 236, y: 286), withAttributes: titleAttributes)

let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14, weight: .medium),
    .foregroundColor: NSColor(calibratedRed: 0.36, green: 0.39, blue: 0.43, alpha: 1)
]
"Drag the app into Applications".draw(at: NSPoint(x: 222, y: 258), withAttributes: subtitleAttributes)

let labelAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
    .foregroundColor: NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.17, alpha: 1)
]
"MeowVault.app".draw(at: NSPoint(x: 103, y: 78), withAttributes: labelAttributes)
"Applications".draw(at: NSPoint(x: 434, y: 78), withAttributes: labelAttributes)

let hintAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .regular),
    .foregroundColor: NSColor(calibratedRed: 0.45, green: 0.48, blue: 0.52, alpha: 1)
]
"Menu bar clipboard history - Cmd+Shift+V".draw(at: NSPoint(x: 214, y: 48), withAttributes: hintAttributes)

let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: 275, y: 190))
arrowPath.line(to: NSPoint(x: 365, y: 190))
arrowPath.move(to: NSPoint(x: 345, y: 210))
arrowPath.line(to: NSPoint(x: 365, y: 190))
arrowPath.line(to: NSPoint(x: 345, y: 170))
NSColor(calibratedRed: 0.18, green: 0.32, blue: 0.46, alpha: 1).setStroke()
arrowPath.lineWidth = 5
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowPath.stroke()

func drawPaw(at point: NSPoint, scale: CGFloat, angle: CGFloat) {
    let transform = NSAffineTransform()
    transform.translateX(by: point.x, yBy: point.y)
    transform.rotate(byDegrees: angle)
    transform.scale(by: scale)
    transform.concat()

    NSColor(calibratedRed: 0.12, green: 0.18, blue: 0.24, alpha: 0.22).setFill()
    NSBezierPath(ovalIn: NSRect(x: -6, y: -7, width: 12, height: 13)).fill()
    NSBezierPath(ovalIn: NSRect(x: -12, y: 5, width: 7, height: 9)).fill()
    NSBezierPath(ovalIn: NSRect(x: -4, y: 9, width: 7, height: 9)).fill()
    NSBezierPath(ovalIn: NSRect(x: 5, y: 5, width: 7, height: 9)).fill()

    transform.invert()
    transform.concat()
}

drawPaw(at: NSPoint(x: 302, y: 225), scale: 1.0, angle: -18)
drawPaw(at: NSPoint(x: 337, y: 153), scale: 0.95, angle: 18)
drawPaw(at: NSPoint(x: 382, y: 220), scale: 1.0, angle: -14)
drawPaw(at: NSPoint(x: 417, y: 150), scale: 0.95, angle: 16)

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("failed to render background")
}

try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
try png.write(to: url)
