#!/usr/bin/env swift

import AppKit
import Foundation

// 图标尺寸 44x44 px = 22pt @2x Retina（菜单栏高度约 24pt）
let size = 44
let rect = CGRect(x: 0, y: 0, width: size, height: size)

// 创建 bitmap context，带 alpha 通道
guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("❌ 无法创建 CGContext")
    exit(1)
}

// 清空为透明
ctx.clear(rect)

// === 1. 绘制实心圆角矩形 ===
let cornerRadius: CGFloat = 10
let outerInset: CGFloat = 1
let outerRect = rect.insetBy(dx: outerInset, dy: outerInset)
let outerPath = CGPath(roundedRect: outerRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
ctx.addPath(outerPath)
ctx.setFillColor(NSColor.black.cgColor)
ctx.fillPath()

// === 2. 齿轮镂空（clear blendMode 擦除） ===
let gearCenter = CGPoint(x: size / 2, y: size / 2)
let teeth = 8
let innerRadius: CGFloat = 7
let outerRadius: CGFloat = 13
let toothArcWidth: CGFloat = 0.22  // 每个齿占的弧度比例

ctx.setBlendMode(.clear)
ctx.setFillColor(NSColor.clear.cgColor)

let gearPath = CGMutablePath()

for i in 0..<teeth {
    let toothMidAngle = (CGFloat(i) / CGFloat(teeth)) * 2 * CGFloat.pi - CGFloat.pi / 2
    let halfToothAngle = toothArcWidth / 2

    // 齿尖 — 外弧
    let toothStart = toothMidAngle - halfToothAngle
    let toothEnd = toothMidAngle + halfToothAngle
    gearPath.addArc(center: gearCenter, radius: outerRadius, startAngle: toothStart, endAngle: toothEnd, clockwise: false)

    // 齿根 — 内弧（反向）
    let notchMidAngle = toothMidAngle + CGFloat.pi / CGFloat(teeth)
    let notchStart = notchMidAngle + halfToothAngle
    let notchEnd = notchMidAngle - halfToothAngle
    gearPath.addArc(center: gearCenter, radius: innerRadius, startAngle: notchStart, endAngle: notchEnd, clockwise: false)
}

gearPath.closeSubpath()
ctx.addPath(gearPath)
ctx.fillPath()

// === 3. 闪电符号（黑色实心，叠加在齿轮镂空区域上方） ===
ctx.setBlendMode(.normal)
ctx.setFillColor(NSColor.black.cgColor)

let cx = CGFloat(size / 2)
let cy = CGFloat(size / 2)
let boltPath = CGMutablePath()
boltPath.move(to: CGPoint(x: cx, y: cy - 7))
boltPath.addLine(to: CGPoint(x: cx + 3, y: cy - 1))
boltPath.addLine(to: CGPoint(x: cx - 1, y: cy))
boltPath.addLine(to: CGPoint(x: cx + 2.5, y: cy + 5))
boltPath.addLine(to: CGPoint(x: cx - 1, y: cy + 6))
boltPath.addLine(to: CGPoint(x: cx - 3.5, y: cy + 1))
boltPath.addLine(to: CGPoint(x: cx + 0.5, y: cy))
boltPath.addLine(to: CGPoint(x: cx - 3.5, y: cy - 3.5))
boltPath.closeSubpath()
ctx.addPath(boltPath)
ctx.fillPath()

// === 导出 PNG ===
guard let cgImage = ctx.makeImage() else {
    print("❌ 无法创建 CGImage")
    exit(1)
}

let outputURL = URL(fileURLWithPath: "Resources/menubar-icon.png")
try? FileManager.default.createDirectory(
    at: URL(fileURLWithPath: "Resources"),
    withIntermediateDirectories: true,
    attributes: nil
)

let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    print("❌ 无法生成 PNG 数据")
    exit(1)
}

try pngData.write(to: outputURL)
print("✅ 图标已生成: \(outputURL.path)")
print("   尺寸: \(size)x\(size)px, 圆角矩形 + \(teeth)齿齿轮")
