import CoreGraphics
import Foundation
import ImageIO

// Measures every Iso25D sprite's ground plate (the diamond-shaped lot base
// baked into the artwork) and regenerates Iso25DSpriteCalibration.swift so the
// renderer scales and anchors each card from measured pixels instead of
// hand-tuned constants.
//
// Usage:
//   swift Tools/calibrate_iso25d_sprites.swift \
//       UsedCarCity/Assets.xcassets UsedCarCity/Iso25DSpriteCalibration.swift
//   swift Tools/calibrate_iso25d_sprites.swift \
//       UsedCarCity/Assets.xcassets UsedCarCity/Iso25DSpriteCalibration.swift \
//       --strict
//
// Detection model: each sprite depicts its full lot as a ground plate whose
// left/right/front corners are the extreme opaque pixels of the lower part of
// the silhouette. Cars, planters and buildings sit on the plate, so within a
// band above the bottom-most pixel the horizontal extremes are the plate
// corners. Overhanging roofs/canopies sit far above that band.

let alphaThreshold: UInt8 = 24
// Plates are at most ~1024 px wide and flatter than height/width 0.7, so the
// left/right corners sit within ~360 px of the front corner. Keeping the band
// tight excludes wide roofs and canopies from corner detection.
let cornerSearchBand = 360
let cornerTolerance = 2
let maximumCornerAsymmetry = 8
let expectedPlateHeightOverWidth = 0.618
let maximumPlateRatioDeviation = 0.020
let maximumFrontCenterOffset = 0.015

struct PlateMeasurement {
    let imageName: String
    let widthFraction: Double
    let anchorX: Double
    let anchorY: Double
    let plateHeightOverWidth: Double
    let warnings: [String]
}

func loadAlphaMask(path: String) -> (mask: [Bool], width: Int, height: Int)? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    let width = image.width
    let height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(
        data: &pixels, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    // Buffer row 0 is the visual top of the image (verified with a probe).
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    var mask = [Bool](repeating: false, count: width * height)
    for index in 0..<(width * height) {
        mask[index] = pixels[index * 4 + 3] > alphaThreshold
    }
    return (mask, width, height)
}

/// Keeps only the largest 4-connected opaque component, dropping detached
/// matting artifacts (e.g. leftover background bands from AI cutouts).
func largestComponent(mask: [Bool], width: Int, height: Int) -> [Bool] {
    var labels = [Int32](repeating: 0, count: mask.count)
    var bestLabel: Int32 = 0
    var bestCount = 0
    var nextLabel: Int32 = 1
    var stack: [Int] = []
    for start in 0..<mask.count where mask[start] && labels[start] == 0 {
        var count = 0
        stack.append(start)
        labels[start] = nextLabel
        while let index = stack.popLast() {
            count += 1
            let x = index % width
            if x > 0, mask[index - 1], labels[index - 1] == 0 {
                labels[index - 1] = nextLabel
                stack.append(index - 1)
            }
            if x + 1 < width, mask[index + 1], labels[index + 1] == 0 {
                labels[index + 1] = nextLabel
                stack.append(index + 1)
            }
            if index >= width, mask[index - width], labels[index - width] == 0 {
                labels[index - width] = nextLabel
                stack.append(index - width)
            }
            if index + width < mask.count, mask[index + width], labels[index + width] == 0 {
                labels[index + width] = nextLabel
                stack.append(index + width)
            }
        }
        if count > bestCount {
            bestCount = count
            bestLabel = nextLabel
        }
        nextLabel += 1
    }
    var result = [Bool](repeating: false, count: mask.count)
    for index in 0..<mask.count where labels[index] == bestLabel {
        result[index] = true
    }
    return result
}

func measurePlate(imageName: String, path: String) -> PlateMeasurement? {
    guard let loaded = loadAlphaMask(path: path) else { return nil }
    let width = loaded.width
    let height = loaded.height
    let mask = largestComponent(mask: loaded.mask, width: width, height: height)

    var rowMinX = [Int](repeating: Int.max, count: height)
    var rowMaxX = [Int](repeating: -1, count: height)
    var bottomRow = -1
    for y in 0..<height {
        for x in 0..<width where mask[y * width + x] {
            if x < rowMinX[y] { rowMinX[y] = x }
            if x > rowMaxX[y] { rowMaxX[y] = x }
        }
        if rowMaxX[y] >= 0 { bottomRow = y }
    }
    guard bottomRow >= 0 else { return nil }

    let bandTop = max(0, bottomRow - cornerSearchBand)
    var leftX = Int.max
    var rightX = -1
    for y in bandTop...bottomRow where rowMaxX[y] >= 0 {
        if rowMinX[y] < leftX { leftX = rowMinX[y] }
        if rowMaxX[y] > rightX { rightX = rowMaxX[y] }
    }
    // The plate corner is the bottom-most row that reaches the horizontal
    // extreme; rows above that match only where a wall rises from the corner.
    var leftCornerRow = bandTop
    var rightCornerRow = bandTop
    for y in bandTop...bottomRow where rowMaxX[y] >= 0 {
        if rowMinX[y] <= leftX + cornerTolerance { leftCornerRow = y }
        if rowMaxX[y] >= rightX - cornerTolerance { rightCornerRow = y }
    }

    let plateWidth = Double(rightX - leftX + 1)
    let centerX = (Double(leftX + rightX) / 2 + 0.5) / Double(width)
    let centerY = (Double(leftCornerRow + rightCornerRow) / 2 + 0.5) / Double(height)
    let halfHeight = Double(bottomRow) - (Double(leftCornerRow + rightCornerRow) / 2)
    let ratio = 2 * halfHeight / plateWidth

    let frontX = Double(rowMinX[bottomRow] + rowMaxX[bottomRow]) / 2 + 0.5
    var warnings: [String] = []
    if abs(leftCornerRow - rightCornerRow) > maximumCornerAsymmetry {
        warnings.append("asymmetric corners: left y=\(leftCornerRow) right y=\(rightCornerRow)")
    }
    if abs(frontX / Double(width) - centerX) > maximumFrontCenterOffset {
        warnings.append(String(
            format: "front corner x=%.3f is off plate center x=%.3f",
            frontX / Double(width), centerX
        ))
    }
    if abs(ratio - expectedPlateHeightOverWidth) > maximumPlateRatioDeviation {
        warnings.append(String(
            format: "plate height/width ratio %.3f differs from %.3f",
            ratio, expectedPlateHeightOverWidth
        ))
    }
    return PlateMeasurement(
        imageName: imageName,
        widthFraction: plateWidth / Double(width),
        anchorX: centerX,
        anchorY: centerY,
        plateHeightOverWidth: ratio,
        warnings: warnings
    )
}

let arguments = CommandLine.arguments
let usesStrictQualityGate = arguments.count == 4 && arguments[3] == "--strict"
guard arguments.count == 3 || usesStrictQualityGate else {
    FileHandle.standardError.write(Data(
        "usage: swift Tools/calibrate_iso25d_sprites.swift <xcassets path> <output swift file> [--strict]\n".utf8
    ))
    exit(1)
}
let assetsPath = arguments[1]
let outputPath = arguments[2]

let fileManager = FileManager.default
let imageSets = ((try? fileManager.contentsOfDirectory(atPath: assetsPath)) ?? [])
    .filter { $0.hasPrefix("Iso25D") && $0.hasSuffix(".imageset") }
    .sorted()

var measurements: [PlateMeasurement] = []
for imageSet in imageSets {
    let directory = assetsPath + "/" + imageSet
    guard let png = ((try? fileManager.contentsOfDirectory(atPath: directory)) ?? [])
        .first(where: { $0.hasSuffix(".png") }) else { continue }
    let imageName = imageSet.replacingOccurrences(of: ".imageset", with: "")
    guard let measurement = measurePlate(imageName: imageName, path: directory + "/" + png) else {
        FileHandle.standardError.write(Data("failed to measure \(imageName)\n".utf8))
        exit(1)
    }
    measurements.append(measurement)
    let flags = measurement.warnings.isEmpty ? "" : "  ⚠ " + measurement.warnings.joined(separator: "; ")
    print(String(
        format: "%@: fraction=%.4f anchor=(%.4f, %.4f) plateH/W=%.3f%@",
        measurement.imageName, measurement.widthFraction,
        measurement.anchorX, measurement.anchorY,
        measurement.plateHeightOverWidth, flags
    ))
}

if usesStrictQualityGate {
    let rejected = measurements.filter { !$0.warnings.isEmpty }
    guard rejected.isEmpty else {
        FileHandle.standardError.write(Data(
            "strict projection gate rejected \(rejected.count) of \(measurements.count) sprites; output was not changed\n".utf8
        ))
        exit(2)
    }
}

var generated = """
// Generated by Tools/calibrate_iso25d_sprites.swift — do not edit by hand.
// Regenerate after changing any Iso25D artwork:
//   swift Tools/calibrate_iso25d_sprites.swift \\
//       UsedCarCity/Assets.xcassets UsedCarCity/Iso25DSpriteCalibration.swift
//
// Each entry locates the artwork's baked ground plate (the lot base diamond):
// the plate's measured pixel width fraction and its center point. The renderer
// scales each card so the plate spans exactly the projected grid footprint and
// anchors the plate center on the footprint center.

struct Iso25DSpriteCalibration: Hashable, Sendable {
    let footprintWidthFraction: Float
    let groundAnchorX: Float
    let groundAnchorY: Float

    static let byImageName: [String: Iso25DSpriteCalibration] = [

"""
for measurement in measurements {
    generated += String(
        format: "        \"%@\": .init(footprintWidthFraction: %.4f, groundAnchorX: %.4f, groundAnchorY: %.4f),\n",
        measurement.imageName, measurement.widthFraction, measurement.anchorX, measurement.anchorY
    )
}
generated += """
    ]
}

"""
try generated.write(toFile: outputPath, atomically: true, encoding: .utf8)
print("\nwrote \(measurements.count) calibrations to \(outputPath)")
