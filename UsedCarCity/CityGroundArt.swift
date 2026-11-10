import UIKit

/// Procedurally drawn, tileable ground textures. Broad tonal patches and a
/// small amount of grain give the terrain a hand-painted strategy-game finish
/// without turning the grid into visual noise.
@MainActor
enum CityGroundArt {
    private static var cache: [String: UIImage] = [:]

    // MARK: - Public surfaces

    /// Two-tone mown lawn. The texture spans 2 x 2 grid cells, so the subtle
    /// checker reads as the build grid of a city-building game.
    static func grassTexture() -> UIImage {
        cached("grass", size: CGSize(width: 256, height: 256)) { size in
            let context = UIGraphicsGetCurrentContext()
            let light = UIColor(red: 0.50, green: 0.74, blue: 0.30, alpha: 1)
            let dark = UIColor(red: 0.45, green: 0.69, blue: 0.27, alpha: 1)
            let half = size.width / 2
            for row in 0..<2 {
                for column in 0..<2 {
                    ((row + column).isMultiple(of: 2) ? light : dark).setFill()
                    context?.fill(CGRect(x: CGFloat(column) * half, y: CGFloat(row) * half, width: half, height: half))
                }
            }
            var generator = SeededGenerator(seed: 5)
            // Short grass tufts and a few clover flowers.
            for index in 0..<220 {
                let x = generator.unit() * size.width
                let y = generator.unit() * size.height
                let bright = index % 3 != 0
                (bright
                    ? UIColor(red: 0.66, green: 0.84, blue: 0.36, alpha: 0.42)
                    : UIColor(red: 0.30, green: 0.55, blue: 0.20, alpha: 0.34)).setFill()
                let width = 1.6 + generator.unit() * 1.4
                let height = 3.0 + generator.unit() * 3.6
                UIBezierPath(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerRadius: width / 2).fill()
            }
            for index in 0..<14 {
                (index.isMultiple(of: 2)
                    ? UIColor(red: 1.0, green: 0.97, blue: 0.80, alpha: 0.85)
                    : UIColor(red: 1.0, green: 0.86, blue: 0.30, alpha: 0.85)).setFill()
                let side = 2.2 + generator.unit() * 1.2
                UIBezierPath(ovalIn: CGRect(
                    x: generator.unit() * size.width, y: generator.unit() * size.height, width: side, height: side
                )).fill()
            }
        }
    }

    static func parkTexture() -> UIImage {
        speckled(
            key: "park",
            base: UIColor(red: 0.54, green: 0.72, blue: 0.33, alpha: 1),
            speckles: [
                (UIColor(red: 0.69, green: 0.80, blue: 0.34, alpha: 0.26), 62, 1.4...3.0),
                (UIColor(red: 0.43, green: 0.61, blue: 0.18, alpha: 0.22), 54, 1.4...3.2),
                (UIColor(red: 0.93, green: 0.74, blue: 0.25, alpha: 0.15), 16, 1.0...2.2)
            ],
            patches: 7,
            patchColor: UIColor(red: 0.62, green: 0.76, blue: 0.30, alpha: 0.28)
        )
    }

    static func sandTexture() -> UIImage {
        speckled(
            key: "sand",
            base: UIColor(red: 0.91, green: 0.77, blue: 0.49, alpha: 1),
            speckles: [
                (UIColor(red: 0.93, green: 0.86, blue: 0.68, alpha: 0.6), 260, 1.0...2.2),
                (UIColor(red: 0.80, green: 0.71, blue: 0.51, alpha: 0.5), 220, 1.0...2.4)
            ],
            patches: 4,
            patchColor: UIColor(red: 0.84, green: 0.76, blue: 0.56, alpha: 0.4)
        )
    }

    static func waterTexture() -> UIImage {
        cached("water", size: CGSize(width: 256, height: 256)) { size in
            UIColor(red: 0.16, green: 0.62, blue: 0.84, alpha: 1).setFill()
            UIGraphicsGetCurrentContext()?.fill(CGRect(origin: .zero, size: size))
            var generator = SeededGenerator(seed: 11)
            // Broad deeper swells under the wave crests.
            for _ in 0..<14 {
                UIColor(red: 0.08, green: 0.50, blue: 0.76, alpha: 0.20).setFill()
                let width = 60 + generator.unit() * 90
                let height = 16 + generator.unit() * 22
                UIBezierPath(ovalIn: CGRect(
                    x: generator.unit() * size.width - width / 2,
                    y: generator.unit() * size.height - height / 2,
                    width: width, height: height
                )).fill()
            }
        }
    }

    /// Transparent wave crests that drift over the water plane.
    static func waveCrestTexture() -> UIImage {
        let key = "wave-crests"
        if let image = cache[key] { return image }
        let size = CGSize(width: 256, height: 256)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            var generator = SeededGenerator(seed: 77)
            for index in 0..<34 {
                let x = generator.unit() * size.width
                let y = generator.unit() * size.height
                let length = 16 + generator.unit() * 30
                let path = UIBezierPath()
                // A shallow "~" crest, drawn twice so it wraps across the seam.
                for wrap in [CGFloat(0), -size.width] {
                    path.move(to: CGPoint(x: x + wrap, y: y))
                    path.addCurve(
                        to: CGPoint(x: x + wrap + length, y: y),
                        controlPoint1: CGPoint(x: x + wrap + length * 0.3, y: y - 4),
                        controlPoint2: CGPoint(x: x + wrap + length * 0.7, y: y + 4)
                    )
                }
                path.lineWidth = 2.2 + generator.unit() * 1.4
                path.lineCapStyle = .round
                UIColor(white: 1, alpha: index.isMultiple(of: 3) ? 0.85 : 0.5).setStroke()
                path.stroke()
            }
        }
        cache[key] = image
        return image
    }

    /// Large soft blob used for drifting cloud shadows.
    static func cloudShadowTexture() -> UIImage {
        let key = "cloud-shadow"
        if let image = cache[key] { return image }
        let size = CGSize(width: 256, height: 256)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(red: 0.04, green: 0.10, blue: 0.22, alpha: 0.20).cgColor,
                    UIColor(red: 0.04, green: 0.10, blue: 0.22, alpha: 0.14).cgColor,
                    UIColor(red: 0.04, green: 0.10, blue: 0.22, alpha: 0).cgColor
                ] as CFArray,
                locations: [0, 0.55, 1]
            )!
            for (x, y, radius) in [(92.0, 128.0, 78.0), (150.0, 112.0, 88.0), (176.0, 150.0, 64.0)] {
                context.cgContext.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: x, y: y), startRadius: 0,
                    endCenter: CGPoint(x: x, y: y), endRadius: radius,
                    options: []
                )
            }
        }
        cache[key] = image
        return image
    }

    static func plazaTexture() -> UIImage {
        cached("plaza") { size in
            UIColor(red: 0.84, green: 0.78, blue: 0.65, alpha: 1).setFill()
            UIGraphicsGetCurrentContext()?.fill(CGRect(origin: .zero, size: size))
            var generator = SeededGenerator(seed: 23)
            for _ in 0..<160 {
                let alpha = 0.05 + generator.unit() * 0.08
                let tone = 0.70 + generator.unit() * 0.16
                UIColor(red: tone, green: tone - 0.01, blue: tone - 0.04, alpha: alpha).setFill()
                UIGraphicsGetCurrentContext()?.fill(CGRect(
                    x: generator.unit() * size.width,
                    y: generator.unit() * size.height,
                    width: 2 + generator.unit() * 3,
                    height: 2 + generator.unit() * 3
                ))
            }
            // Paver grid.
            UIColor(red: 0.68, green: 0.66, blue: 0.61, alpha: 0.55).setFill()
            let step = size.width / 4
            for index in 0...4 {
                UIGraphicsGetCurrentContext()?.fill(CGRect(x: CGFloat(index) * step - 0.5, y: 0, width: 1, height: size.height))
                UIGraphicsGetCurrentContext()?.fill(CGRect(x: 0, y: CGFloat(index) * step - 0.5, width: size.width, height: 1))
            }
        }
    }

    static func sidewalkTexture() -> UIImage {
        cached("sidewalk") { size in
            UIColor(red: 0.80, green: 0.76, blue: 0.66, alpha: 1).setFill()
            UIGraphicsGetCurrentContext()?.fill(CGRect(origin: .zero, size: size))
            var generator = SeededGenerator(seed: 31)
            for _ in 0..<170 {
                let alpha = 0.04 + generator.unit() * 0.07
                let tone = 0.66 + generator.unit() * 0.18
                UIColor(red: tone, green: tone - 0.02, blue: tone - 0.06, alpha: alpha).setFill()
                UIGraphicsGetCurrentContext()?.fill(CGRect(
                    x: generator.unit() * size.width,
                    y: generator.unit() * size.height,
                    width: 1.6 + generator.unit() * 2.6,
                    height: 1.6 + generator.unit() * 2.6
                ))
            }
            UIColor(red: 0.64, green: 0.62, blue: 0.56, alpha: 0.4).setFill()
            let step = size.width / 2
            for index in 0...2 {
                UIGraphicsGetCurrentContext()?.fill(CGRect(x: CGFloat(index) * step - 0.5, y: 0, width: 1, height: size.height))
                UIGraphicsGetCurrentContext()?.fill(CGRect(x: 0, y: CGFloat(index) * step - 0.5, width: size.width, height: 1))
            }
        }
    }

    static func asphaltTexture(brightness: CGFloat) -> UIImage {
        cached(String(format: "asphalt-%.2f", brightness)) { size in
            UIColor(
                red: brightness,
                green: brightness + 0.015,
                blue: brightness + 0.03,
                alpha: 1
            ).setFill()
            UIGraphicsGetCurrentContext()?.fill(CGRect(origin: .zero, size: size))
            var generator = SeededGenerator(seed: UInt64(brightness * 991) + 7)
            for _ in 0..<90 {
                let alpha = 0.035 + generator.unit() * 0.065
                let tone = brightness + (generator.unit() - 0.45) * 0.16
                UIColor(red: tone, green: tone + 0.01, blue: tone + 0.02, alpha: alpha).setFill()
                UIGraphicsGetCurrentContext()?.fill(CGRect(
                    x: generator.unit() * size.width,
                    y: generator.unit() * size.height,
                    width: 1.2 + generator.unit() * 2.2,
                    height: 1.2 + generator.unit() * 2.2
                ))
            }
        }
    }

    static func gravelTexture() -> UIImage {
        speckled(
            key: "gravel",
            base: UIColor(red: 0.73, green: 0.63, blue: 0.45, alpha: 1),
            speckles: [
                (UIColor(red: 0.79, green: 0.74, blue: 0.62, alpha: 0.25), 140, 0.8...1.8),
                (UIColor(red: 0.62, green: 0.56, blue: 0.44, alpha: 0.22), 130, 0.8...1.8)
            ],
            patches: 4,
            patchColor: UIColor(red: 0.68, green: 0.62, blue: 0.49, alpha: 0.4)
        )
    }

    /// Soft radial shadow used to ground buildings and trees without a
    /// depth-map shadow pass.
    static func blobShadowTexture() -> UIImage {
        let key = "blob-shadow"
        if let image = cache[key] { return image }
        let size = CGSize(width: 64, height: 64)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let colors = [
                UIColor(white: 0.05, alpha: 0.34).cgColor,
                UIColor(white: 0.05, alpha: 0.0).cgColor
            ]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            )!
            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: 32, y: 32), startRadius: 4,
                endCenter: CGPoint(x: 32, y: 32), endRadius: 32,
                options: []
            )
        }
        cache[key] = image
        return image
    }

    /// White board with a red 「売地」 label and a thin frame.
    static func forSaleSignTexture() -> UIImage {
        cached("for-sale-sign", size: CGSize(width: 256, height: 160)) { size in
            UIColor(white: 0.98, alpha: 1).setFill()
            UIGraphicsGetCurrentContext()?.fill(CGRect(origin: .zero, size: size))
            let border = UIBezierPath(rect: CGRect(x: 6, y: 6, width: size.width - 12, height: size.height - 12))
            border.lineWidth = 6
            UIColor(red: 0.82, green: 0.22, blue: 0.16, alpha: 1).setStroke()
            border.stroke()

            let title = "売地" as NSString
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 74, weight: .heavy),
                .foregroundColor: UIColor(red: 0.82, green: 0.22, blue: 0.16, alpha: 1)
            ]
            let titleSize = title.size(withAttributes: titleAttributes)
            title.draw(
                at: CGPoint(x: (size.width - titleSize.width) / 2, y: 18),
                withAttributes: titleAttributes
            )

            let caption = "翠浜不動産" as NSString
            let captionAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26, weight: .bold),
                .foregroundColor: UIColor(white: 0.25, alpha: 1)
            ]
            let captionSize = caption.size(withAttributes: captionAttributes)
            caption.draw(
                at: CGPoint(x: (size.width - captionSize.width) / 2, y: size.height - 44),
                withAttributes: captionAttributes
            )
        }
    }

    // MARK: - Drawing helpers

    private static func speckled(
        key: String,
        base: UIColor,
        speckles: [(UIColor, Int, ClosedRange<CGFloat>)],
        patches: Int,
        patchColor: UIColor
    ) -> UIImage {
        cached(key) { size in
            base.setFill()
            UIGraphicsGetCurrentContext()?.fill(CGRect(origin: .zero, size: size))
            var generator = SeededGenerator(seed: UInt64(key.utf8.reduce(5, { $0 &* 31 &+ UInt64($1) })))
            for _ in 0..<patches {
                patchColor.setFill()
                let width = 20 + generator.unit() * 52
                let height = 14 + generator.unit() * 40
                UIBezierPath(ovalIn: CGRect(
                    x: generator.unit() * size.width - width / 2,
                    y: generator.unit() * size.height - height / 2,
                    width: width,
                    height: height
                )).fill()
            }
            for (color, count, sizes) in speckles {
                color.setFill()
                for _ in 0..<count {
                    let side = sizes.lowerBound + generator.unit() * (sizes.upperBound - sizes.lowerBound)
                    UIGraphicsGetCurrentContext()?.fill(CGRect(
                        x: generator.unit() * size.width,
                        y: generator.unit() * size.height,
                        width: side,
                        height: side
                    ))
                }
            }
        }
    }

    // CGContext.fill keeps normal alpha compositing. UIRectFill uses copy
    // blending, which turned translucent grain into dark holes in an opaque
    // texture once SceneKit sampled it against the terrain.
    private static func cached(
        _ key: String,
        size: CGSize = CGSize(width: 128, height: 128),
        draw: (CGSize) -> Void
    ) -> UIImage {
        if let image = cache[key] { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(size)
        }
        cache[key] = image
        return image
    }

    /// Deterministic pseudo-random stream so textures never shimmer between
    /// launches.
    struct SeededGenerator {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed &+ 0x9E37_79B9_7F4A_7C15
        }

        mutating func unit() -> CGFloat {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let value = (state >> 33) % 100_000
            return CGFloat(value) / 100_000
        }
    }
}
