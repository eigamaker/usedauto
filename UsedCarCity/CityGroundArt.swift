import UIKit

/// Procedurally drawn, tileable ground textures. Everything is generated once
/// and cached, so the map ships zero raster assets while still reading as
/// painted ground instead of flat vector fills.
@MainActor
enum CityGroundArt {
    private static var cache: [String: UIImage] = [:]

    // MARK: - Public surfaces

    static func grassTexture() -> UIImage {
        speckled(
            key: "grass",
            base: UIColor(red: 0.47, green: 0.63, blue: 0.35, alpha: 1),
            speckles: [
                (UIColor(red: 0.54, green: 0.70, blue: 0.40, alpha: 0.55), 260, 1.2...2.6),
                (UIColor(red: 0.40, green: 0.55, blue: 0.29, alpha: 0.50), 240, 1.2...2.8),
                (UIColor(red: 0.62, green: 0.74, blue: 0.42, alpha: 0.30), 90, 2.0...4.5)
            ],
            patches: 7,
            patchColor: UIColor(red: 0.43, green: 0.60, blue: 0.32, alpha: 0.35)
        )
    }

    static func parkTexture() -> UIImage {
        speckled(
            key: "park",
            base: UIColor(red: 0.52, green: 0.68, blue: 0.38, alpha: 1),
            speckles: [
                (UIColor(red: 0.60, green: 0.75, blue: 0.44, alpha: 0.55), 250, 1.2...2.6),
                (UIColor(red: 0.45, green: 0.61, blue: 0.32, alpha: 0.50), 220, 1.2...2.8),
                (UIColor(red: 0.86, green: 0.83, blue: 0.55, alpha: 0.25), 40, 1.0...2.0)
            ],
            patches: 6,
            patchColor: UIColor(red: 0.57, green: 0.72, blue: 0.41, alpha: 0.35)
        )
    }

    static func sandTexture() -> UIImage {
        speckled(
            key: "sand",
            base: UIColor(red: 0.88, green: 0.80, blue: 0.60, alpha: 1),
            speckles: [
                (UIColor(red: 0.93, green: 0.86, blue: 0.68, alpha: 0.6), 260, 1.0...2.2),
                (UIColor(red: 0.80, green: 0.71, blue: 0.51, alpha: 0.5), 220, 1.0...2.4)
            ],
            patches: 4,
            patchColor: UIColor(red: 0.84, green: 0.76, blue: 0.56, alpha: 0.4)
        )
    }

    static func waterTexture() -> UIImage {
        cached("water") { size in
            UIColor(red: 0.33, green: 0.60, blue: 0.78, alpha: 1).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            var generator = SeededGenerator(seed: 11)
            // Horizontal glints suggest ripples without any animation cost.
            for _ in 0..<70 {
                let alpha = 0.05 + generator.unit() * 0.10
                UIColor(red: 0.55, green: 0.78, blue: 0.90, alpha: alpha).setFill()
                let width = 6 + generator.unit() * 26
                let rect = CGRect(
                    x: generator.unit() * size.width,
                    y: generator.unit() * size.height,
                    width: width,
                    height: 1.0 + generator.unit() * 1.4
                )
                UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2).fill()
            }
            for _ in 0..<26 {
                let alpha = 0.05 + generator.unit() * 0.07
                UIColor(red: 0.20, green: 0.44, blue: 0.64, alpha: alpha).setFill()
                let width = 8 + generator.unit() * 30
                let rect = CGRect(
                    x: generator.unit() * size.width,
                    y: generator.unit() * size.height,
                    width: width,
                    height: 1.2 + generator.unit() * 1.6
                )
                UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2).fill()
            }
        }
    }

    static func plazaTexture() -> UIImage {
        cached("plaza") { size in
            UIColor(red: 0.80, green: 0.78, blue: 0.73, alpha: 1).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            var generator = SeededGenerator(seed: 23)
            for _ in 0..<160 {
                let alpha = 0.05 + generator.unit() * 0.08
                let tone = 0.70 + generator.unit() * 0.16
                UIColor(red: tone, green: tone - 0.01, blue: tone - 0.04, alpha: alpha).setFill()
                UIRectFill(CGRect(
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
                UIRectFill(CGRect(x: CGFloat(index) * step - 0.5, y: 0, width: 1, height: size.height))
                UIRectFill(CGRect(x: 0, y: CGFloat(index) * step - 0.5, width: size.width, height: 1))
            }
        }
    }

    static func sidewalkTexture() -> UIImage {
        cached("sidewalk") { size in
            UIColor(red: 0.76, green: 0.74, blue: 0.68, alpha: 1).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            var generator = SeededGenerator(seed: 31)
            for _ in 0..<170 {
                let alpha = 0.04 + generator.unit() * 0.07
                let tone = 0.66 + generator.unit() * 0.18
                UIColor(red: tone, green: tone - 0.02, blue: tone - 0.06, alpha: alpha).setFill()
                UIRectFill(CGRect(
                    x: generator.unit() * size.width,
                    y: generator.unit() * size.height,
                    width: 1.6 + generator.unit() * 2.6,
                    height: 1.6 + generator.unit() * 2.6
                ))
            }
            UIColor(red: 0.64, green: 0.62, blue: 0.56, alpha: 0.4).setFill()
            let step = size.width / 2
            for index in 0...2 {
                UIRectFill(CGRect(x: CGFloat(index) * step - 0.5, y: 0, width: 1, height: size.height))
                UIRectFill(CGRect(x: 0, y: CGFloat(index) * step - 0.5, width: size.width, height: 1))
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
            UIRectFill(CGRect(origin: .zero, size: size))
            var generator = SeededGenerator(seed: UInt64(brightness * 991) + 7)
            for _ in 0..<240 {
                let alpha = 0.05 + generator.unit() * 0.09
                let tone = brightness + (generator.unit() - 0.45) * 0.16
                UIColor(red: tone, green: tone + 0.01, blue: tone + 0.02, alpha: alpha).setFill()
                UIRectFill(CGRect(
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
            base: UIColor(red: 0.72, green: 0.66, blue: 0.53, alpha: 1),
            speckles: [
                (UIColor(red: 0.79, green: 0.74, blue: 0.62, alpha: 0.6), 250, 1.2...2.6),
                (UIColor(red: 0.62, green: 0.56, blue: 0.44, alpha: 0.55), 230, 1.2...2.6)
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
            UIRectFill(CGRect(origin: .zero, size: size))
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
            UIRectFill(CGRect(origin: .zero, size: size))
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
                    UIRectFill(CGRect(
                        x: generator.unit() * size.width,
                        y: generator.unit() * size.height,
                        width: side,
                        height: side
                    ))
                }
            }
        }
    }

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
