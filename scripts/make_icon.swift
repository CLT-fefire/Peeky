#!/usr/bin/env swift
// Peeky 마스코트 아이콘 생성기.
// 디자인: 둥근 사각 배경 (cyan→indigo 그라데이션) + 흰색 돋보기 + 돋보기 안 작은 눈
// 출력: Resources/AppIcon.icns (멀티 해상도: 16, 32, 128, 256, 512px @1x/@2x)
//
// 실행: swift scripts/make_icon.swift

import AppKit
import CoreGraphics

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let outputDir = "Resources/AppIcon.iconset"
let icnsPath = "Resources/AppIcon.icns"

try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

func makeIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    // 1. 둥근 사각 배경 + 그라데이션 (cyan → indigo)
    let cornerRadius = s * 0.225  // macOS 26 squircle 비율
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(red: 0.30, green: 0.78, blue: 0.92, alpha: 1.0),  // top: cyan
            CGColor(red: 0.36, green: 0.42, blue: 0.93, alpha: 1.0),  // bottom: indigo
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

    // 2. 미세한 하이라이트 — 상단 빛 반사
    let highlightGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.25),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(highlightGradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: s * 0.5), options: [])

    // 3. 돋보기 — 렌즈 (큰 원, 우상단 약간 안쪽)
    let lensCenter = CGPoint(x: s * 0.46, y: s * 0.54)
    let lensRadius = s * 0.27
    let lensRect = CGRect(
        x: lensCenter.x - lensRadius,
        y: lensCenter.y - lensRadius,
        width: lensRadius * 2,
        height: lensRadius * 2
    )

    // 렌즈 안쪽 — 살짝 어두운 배경 (눈이 잘 보이게)
    ctx.saveGState()
    ctx.setFillColor(CGColor(red: 0.10, green: 0.15, blue: 0.30, alpha: 0.35))
    ctx.fillEllipse(in: lensRect)
    ctx.restoreGState()

    // 4. 눈동자 — 렌즈 중앙에 큰 흰자 + 검은 눈동자 + 작은 하이라이트
    let eyeWhiteRadius = lensRadius * 0.65
    let eyeRect = CGRect(
        x: lensCenter.x - eyeWhiteRadius,
        y: lensCenter.y - eyeWhiteRadius * 0.7,
        width: eyeWhiteRadius * 2,
        height: eyeWhiteRadius * 1.4
    )
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    ctx.fillEllipse(in: eyeRect)

    let pupilRadius = eyeWhiteRadius * 0.45
    let pupilRect = CGRect(
        x: lensCenter.x - pupilRadius,
        y: lensCenter.y - pupilRadius * 0.9,
        width: pupilRadius * 2,
        height: pupilRadius * 1.8
    )
    ctx.setFillColor(CGColor(red: 0.08, green: 0.10, blue: 0.18, alpha: 1.0))
    ctx.fillEllipse(in: pupilRect)

    // 눈동자 하이라이트
    let highlightRadius = pupilRadius * 0.35
    let highlightRect = CGRect(
        x: lensCenter.x - highlightRadius * 0.3,
        y: lensCenter.y + pupilRadius * 0.3,
        width: highlightRadius * 2,
        height: highlightRadius * 2
    )
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    ctx.fillEllipse(in: highlightRect)

    // 5. 돋보기 테두리 — 흰색 두꺼운 링
    let ringWidth = s * 0.055
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.98))
    ctx.setLineWidth(ringWidth)
    ctx.strokeEllipse(in: lensRect)

    // 6. 돋보기 손잡이 — 좌하단 방향 둥근 사각형
    let handleStart = CGPoint(
        x: lensCenter.x - lensRadius * cos(.pi / 4) - ringWidth * 0.3,
        y: lensCenter.y - lensRadius * sin(.pi / 4) + ringWidth * 0.3
    )
    let handleLength = s * 0.28
    let handleEnd = CGPoint(
        x: handleStart.x - handleLength * cos(.pi / 4),
        y: handleStart.y - handleLength * sin(.pi / 4)
    )
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.98))
    ctx.setLineWidth(s * 0.075)
    ctx.setLineCap(.round)
    ctx.move(to: handleStart)
    ctx.addLine(to: handleEnd)
    ctx.strokePath()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        print("✗ PNG 변환 실패: \(path)")
        return
    }
    try? png.write(to: URL(fileURLWithPath: path))
}

// .iconset 디렉토리에 표준 파일명으로 출력
let iconsetMapping: [(name: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, size) in iconsetMapping {
    let img = makeIcon(size: size)
    writePNG(img, to: "\(outputDir)/\(name)")
    print("✓ \(name) (\(size)px)")
}

// iconutil로 .icns 합치기
let proc = Process()
proc.launchPath = "/usr/bin/iconutil"
proc.arguments = ["-c", "icns", outputDir, "-o", icnsPath]
try? proc.run()
proc.waitUntilExit()

print("✅ \(icnsPath)")
