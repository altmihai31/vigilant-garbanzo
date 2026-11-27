import UIKit

/// Drawn stand-ins for preview images in demo mode, so screenshots look like the mockup without network.
enum DemoArt {
    private static var cache: [String: UIImage] = [:]

    static func image(named name: String) -> UIImage {
        if let c = cache[name] { return c }
        let size = CGSize(width: 640, height: 440)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let img = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let g = ctx.cgContext
            func gradient(_ colors: [UIColor], from: CGPoint, to: CGPoint, in rect: CGRect? = nil) {
                g.saveGState()
                if let rect { g.clip(to: rect) }
                let cg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: nil)!
                g.drawLinearGradient(cg, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                g.restoreGState()
            }
            func fill(_ c: UIColor, _ path: UIBezierPath) { c.setFill(); path.fill() }
            func hex(_ s: String) -> UIColor {
                var v: UInt64 = 0
                Scanner(string: s).scanHexInt64(&v)
                return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
            }
            let W = size.width, H = size.height
            switch name {
            case "coast", "lisbon":
                gradient([hex("7cc4f2"), hex("bfe3f5")], from: .zero, to: CGPoint(x: 0, y: H * 0.55), in: CGRect(x: 0, y: 0, width: W, height: H * 0.56))
                gradient([hex("1f7fb6"), hex("0b4a78")], from: CGPoint(x: 0, y: H * 0.56), to: CGPoint(x: 0, y: H), in: CGRect(x: 0, y: H * 0.56, width: W, height: H))
                let cliff = UIBezierPath()
                cliff.move(to: CGPoint(x: 0, y: 140)); cliff.addCurve(to: CGPoint(x: 240, y: 320), controlPoint1: CGPoint(x: 80, y: 120), controlPoint2: CGPoint(x: 160, y: 200))
                cliff.addLine(to: CGPoint(x: 160, y: H)); cliff.addLine(to: CGPoint(x: 0, y: H)); cliff.close()
                fill(hex(name == "lisbon" ? "c9785a" : "7a6a52"), cliff)
                let green = UIBezierPath()
                green.move(to: CGPoint(x: 0, y: 180)); green.addCurve(to: CGPoint(x: 160, y: 280), controlPoint1: CGPoint(x: 70, y: 170), controlPoint2: CGPoint(x: 120, y: 220))
                green.addLine(to: CGPoint(x: 120, y: H)); green.addLine(to: CGPoint(x: 0, y: H)); green.close()
                fill(hex(name == "lisbon" ? "e8b27c" : "5b8c4a"), green)
                for (i, r) in [CGRect(x: 40, y: 192, width: 28, height: 24), CGRect(x: 76, y: 208, width: 20, height: 20), CGRect(x: 28, y: 232, width: 36, height: 28),
                               CGRect(x: 80, y: 244, width: 24, height: 24), CGRect(x: 116, y: 264, width: 20, height: 20)].enumerated() {
                    fill(i == 3 ? hex("f2c9a0") : hex("f4e7d0"), UIBezierPath(rect: r))
                }
                fill(UIColor(red: 1, green: 0.96, blue: 0.85, alpha: 0.9), UIBezierPath(ovalIn: CGRect(x: 492, y: 48, width: 64, height: 64)))
            case "sushi", "ramen":
                fill(hex("1a1512"), UIBezierPath(rect: CGRect(origin: .zero, size: size)))
                fill(hex("3a2a1e"), UIBezierPath(rect: CGRect(x: 0, y: 240, width: W, height: 200)))
                if name == "ramen" {
                    fill(hex("efe6d6"), UIBezierPath(ovalIn: CGRect(x: 130, y: 110, width: 380, height: 260)))
                    fill(hex("d89b4a"), UIBezierPath(ovalIn: CGRect(x: 160, y: 130, width: 320, height: 200)))
                    fill(hex("f6d36b"), UIBezierPath(ovalIn: CGRect(x: 220, y: 170, width: 70, height: 60)))
                    fill(hex("2f5d2a"), UIBezierPath(rect: CGRect(x: 330, y: 160, width: 60, height: 90)))
                    fill(hex("c96d5b"), UIBezierPath(ovalIn: CGRect(x: 300, y: 230, width: 90, height: 60)))
                } else {
                    for (x, top) in [(120.0, "ff7a52"), (320.0, "c8243c"), (516.0, "f2c14e")] {
                        fill(hex("f4f1ea"), UIBezierPath(ovalIn: CGRect(x: x - 84, y: 236, width: 168, height: 64)))
                        let p = UIBezierPath()
                        p.move(to: CGPoint(x: x - 88, y: 250)); p.addQuadCurve(to: CGPoint(x: x + 88, y: 250), controlPoint: CGPoint(x: x, y: 180))
                        p.addQuadCurve(to: CGPoint(x: x - 88, y: 250), controlPoint: CGPoint(x: x, y: 270)); fill(hex(top), p)
                    }
                }
            case "phones":
                gradient([hex("e9e4dc"), hex("c9c1b5")], from: .zero, to: CGPoint(x: W, y: H))
                let band = UIBezierPath()
                band.move(to: CGPoint(x: 170, y: 330)); band.addCurve(to: CGPoint(x: 470, y: 330), controlPoint1: CGPoint(x: 170, y: 40), controlPoint2: CGPoint(x: 470, y: 40))
                hex("2b2b2d").setStroke(); band.lineWidth = 34; band.stroke()
                fill(hex("2b2b2d"), UIBezierPath(roundedRect: CGRect(x: 120, y: 250, width: 110, height: 150), cornerRadius: 50))
                fill(hex("2b2b2d"), UIBezierPath(roundedRect: CGRect(x: 410, y: 250, width: 110, height: 150), cornerRadius: 50))
            case "gnocchi", "cacio":
                fill(hex("2a1f18"), UIBezierPath(rect: CGRect(origin: .zero, size: size)))
                fill(hex("d9d4cc"), UIBezierPath(ovalIn: CGRect(x: 90, y: 40, width: 460, height: 360)))
                fill(hex(name == "cacio" ? "f3e2b0" : "e9b35f"), UIBezierPath(ovalIn: CGRect(x: 140, y: 80, width: 360, height: 280)))
                for i in 0..<14 {
                    let x = 180.0 + Double((i * 53) % 260), y = 120.0 + Double((i * 37) % 190)
                    if name == "cacio" {
                        let p = UIBezierPath(); p.move(to: CGPoint(x: x, y: y)); p.addQuadCurve(to: CGPoint(x: x + 90, y: y + 30), controlPoint: CGPoint(x: x + 40, y: y - 40))
                        hex("e7cf8a").setStroke(); p.lineWidth = 7; p.stroke()
                    } else {
                        fill(hex(i % 3 == 0 ? "3f6b2c" : (i % 3 == 1 ? "d8432c" : "f0c878")), UIBezierPath(ovalIn: CGRect(x: x, y: y, width: 38, height: 28)))
                    }
                }
                if name == "cacio" {
                    for i in 0..<40 { fill(.black, UIBezierPath(ovalIn: CGRect(x: 170 + (i * 67) % 300, y: 110 + (i * 41) % 220, width: 5, height: 5))) }
                }
            case "car":
                gradient([hex("2a2f3a"), hex("0d0f14")], from: .zero, to: CGPoint(x: 0, y: H))
                fill(UIColor.black.withAlphaComponent(0.6), UIBezierPath(ovalIn: CGRect(x: 40, y: 320, width: 560, height: 30)))
                let body = UIBezierPath()
                body.move(to: CGPoint(x: 60, y: 300)); body.addQuadCurve(to: CGPoint(x: 180, y: 224), controlPoint: CGPoint(x: 80, y: 240))
                body.addQuadCurve(to: CGPoint(x: 380, y: 176), controlPoint: CGPoint(x: 260, y: 172)); body.addQuadCurve(to: CGPoint(x: 540, y: 232), controlPoint: CGPoint(x: 480, y: 184))
                body.addQuadCurve(to: CGPoint(x: 592, y: 300), controlPoint: CGPoint(x: 592, y: 244)); body.close()
                g.saveGState(); body.addClip()
                gradient([hex("9aa3ad"), hex("e8edf2"), hex("7d8690")], from: CGPoint(x: 60, y: 0), to: CGPoint(x: 592, y: 0)); g.restoreGState()
                fill(hex("111111"), UIBezierPath(ovalIn: CGRect(x: 132, y: 264, width: 80, height: 80)))
                fill(hex("111111"), UIBezierPath(ovalIn: CGRect(x: 448, y: 264, width: 80, height: 80)))
                fill(hex("ff3b30"), UIBezierPath(roundedRect: CGRect(x: 540, y: 252, width: 36, height: 8), cornerRadius: 4))
            case "court":
                fill(hex("c98a4b"), UIBezierPath(rect: CGRect(origin: .zero, size: size)))
                UIColor.white.withAlphaComponent(0.85).setStroke()
                let lines = UIBezierPath(rect: CGRect(x: 200, y: -20, width: 240, height: 240)); lines.lineWidth = 6; lines.stroke()
                let circle = UIBezierPath(ovalIn: CGRect(x: 240, y: 140, width: 160, height: 160)); circle.lineWidth = 6; circle.stroke()
                fill(hex("e46a1f"), UIBezierPath(ovalIn: CGRect(x: 408, y: 288, width: 104, height: 104)))
            case "code":
                fill(hex("151a24"), UIBezierPath(rect: CGRect(origin: .zero, size: size)))
                fill(hex("1e2533"), UIBezierPath(rect: CGRect(x: 0, y: 0, width: W, height: 52)))
                for (i, c) in ["ff5f57", "febc2e", "28c840"].enumerated() { fill(hex(c), UIBezierPath(ovalIn: CGRect(x: 22 + i * 32, y: 16, width: 20, height: 20))) }
                let rows: [[(CGFloat, String)]] = [[(90, "c678dd"), (200, "e5c07b"), (110, "abb2bf")], [(60, "c678dd"), (80, "e06c75"), (170, "abb2bf")],
                                                   [(300, "61afef"), (30, "abb2bf")], [(110, "61afef"), (90, "98c379")], [(200, "61afef"), (50, "abb2bf")]]
                for (r, segs) in rows.enumerated() {
                    var x: CGFloat = 36 + CGFloat(min(r, 3)) * 30
                    for (w, c) in segs { fill(hex(c), UIBezierPath(roundedRect: CGRect(x: x, y: 90 + CGFloat(r) * 52, width: w, height: 18), cornerRadius: 5)); x += w + 14 }
                }
            default: // mountain
                gradient([hex("f6a670"), hex("f7d1a1"), hex("e9b78c")], from: .zero, to: CGPoint(x: 0, y: H))
                let back = UIBezierPath()
                back.move(to: CGPoint(x: 0, y: 330)); back.addLine(to: CGPoint(x: 150, y: 120)); back.addLine(to: CGPoint(x: 250, y: 220))
                back.addLine(to: CGPoint(x: 380, y: 70)); back.addLine(to: CGPoint(x: 520, y: 230)); back.addLine(to: CGPoint(x: W, y: 150))
                back.addLine(to: CGPoint(x: W, y: H)); back.addLine(to: CGPoint(x: 0, y: H)); back.close()
                fill(hex("8a6f8f"), back)
                let front = UIBezierPath()
                front.move(to: CGPoint(x: 0, y: 360)); front.addCurve(to: CGPoint(x: W, y: 330), controlPoint1: CGPoint(x: 200, y: 300), controlPoint2: CGPoint(x: 420, y: 400))
                front.addLine(to: CGPoint(x: W, y: H)); front.addLine(to: CGPoint(x: 0, y: H)); front.close()
                fill(hex("4d6b4a"), front)
            }
        }
        cache[name] = img
        return img
    }
}
