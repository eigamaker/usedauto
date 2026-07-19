import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Repairs a sprite whose AI cutout left the (near-black) backdrop opaque:
// flood-fills from the image border across pixels that are either already
// transparent or near-black, and makes that region fully transparent. Interior
// dark pixels (windows, tires, shadows on the plate) stay untouched because
// they are not border-connected through near-black paths.
//
// Usage: swift Tools/repair_sprite_matte.swift <png path> [<png path> ...]

let alphaThreshold: UInt8 = 24
let blackThreshold: UInt8 = 30

func repair(path: String) -> Bool {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return false }
    let width = image.width
    let height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(
        data: &pixels, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return false }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    func isBackdrop(_ index: Int) -> Bool {
        let alpha = pixels[index * 4 + 3]
        if alpha <= alphaThreshold { return true }
        return pixels[index * 4] <= blackThreshold
            && pixels[index * 4 + 1] <= blackThreshold
            && pixels[index * 4 + 2] <= blackThreshold
    }

    var visited = [Bool](repeating: false, count: width * height)
    var stack: [Int] = []
    for x in 0..<width {
        stack.append(x)
        stack.append((height - 1) * width + x)
    }
    for y in 0..<height {
        stack.append(y * width)
        stack.append(y * width + width - 1)
    }
    var cleared = 0
    while let index = stack.popLast() {
        if visited[index] || !isBackdrop(index) { continue }
        visited[index] = true
        if pixels[index * 4 + 3] > 0 { cleared += 1 }
        pixels[index * 4] = 0
        pixels[index * 4 + 1] = 0
        pixels[index * 4 + 2] = 0
        pixels[index * 4 + 3] = 0
        let x = index % width
        if x > 0 { stack.append(index - 1) }
        if x + 1 < width { stack.append(index + 1) }
        if index >= width { stack.append(index - width) }
        if index + width < width * height { stack.append(index + width) }
    }
    guard cleared > 0 else {
        print("\(path): nothing to repair")
        return true
    }
    guard let repaired = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil
          ) else { return false }
    CGImageDestinationAddImage(destination, repaired, nil)
    guard CGImageDestinationFinalize(destination) else { return false }
    print("\(path): cleared \(cleared) opaque backdrop pixels")
    return true
}

for path in CommandLine.arguments.dropFirst() {
    guard repair(path: path) else {
        FileHandle.standardError.write(Data("failed to repair \(path)\n".utf8))
        exit(1)
    }
}
