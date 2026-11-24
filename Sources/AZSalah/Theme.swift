import SwiftUI
import AppKit

// MARK: - AZ brand palette

enum AZ {
    static let night = Color(hex: 0x050B24)
    static let navy = Color(hex: 0x061230)
    static let ink = Color(hex: 0x0D1A45)
    static let indigo = Color(hex: 0x24308A)
    static let royal = Color(hex: 0x004ACC)   // brand blue from Logo.svg
    static let violet = Color(hex: 0x5968F3)
    static let lime = Color(hex: 0xD4FF24)
    static let gold = Color(hex: 0xE9C46A)
    static let muted = Color(hex: 0xA9B5D6)
    static let line = Color.white.opacity(0.10)

    static let deepGradient = LinearGradient(colors: [night, navy, indigo.opacity(0.9)],
                                             startPoint: .top, endPoint: .bottom)
    static let cardGradient = LinearGradient(colors: [Color.white.opacity(0.09), Color.white.opacity(0.03)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
    static let accentGradient = LinearGradient(colors: [lime, Color(hex: 0x9CF06B)],
                                               startPoint: .leading, endPoint: .trailing)


}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
}

// MARK: - Arabic formatting

enum AR {
    static var locale: Locale { Lang.locale }
    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter(); f.locale = locale; f.numberStyle = .none; return f
    }()

    static func num(_ n: Int) -> String { numberFormatter.string(from: NSNumber(value: n)) ?? "\(n)" }

    static func time(_ date: Date, tz: TimeZone, ampm: Bool = false) -> String {
        let f = DateFormatter()
        f.locale = locale; f.timeZone = tz
        f.dateFormat = ampm ? "h:mm a" : "h:mm"
        return f.string(from: date)
    }

    static func weekday(_ date: Date, tz: TimeZone) -> String {
        let f = DateFormatter(); f.locale = locale; f.timeZone = tz; f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    /// Short countdown: "٢٣ د" / "١:٠٥ س" / "٤٠ ث".
    static func countdown(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        if s >= 3600 { return trf("%@:%@ س", num(s / 3600), pad(s % 3600 / 60)) }
        if s >= 60 { return trf("%@ د", num(Int((Double(s) / 60).rounded(.up)))) }
        return trf("%@ ث", num(s))
    }

    /// Clock style "٠٩:٤٢".
    static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        return "\(pad(s / 60)):\(pad(s % 60))"
    }

    private static func pad(_ n: Int) -> String {
        let f = NumberFormatter(); f.locale = locale; f.minimumIntegerDigits = 2
        return f.string(from: NSNumber(value: n)) ?? String(format: "%02d", n)
    }
}

// MARK: - Islamic geometry

/// Eight-pointed star (Rub el Hizb): two overlapping squares.
struct EightPointStar: Shape {
    var inset: CGFloat = 0
    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let c = CGPoint(x: r.midX, y: r.midY)
        let R = min(r.width, r.height) / 2
        var p = Path()
        for k in 0..<2 {
            let base = Double(k) * .pi / 4
            var pts: [CGPoint] = []
            for i in 0..<4 {
                let a = base + Double(i) * .pi / 2 - .pi / 4
                pts.append(CGPoint(x: c.x + R * CGFloat(cos(a)), y: c.y + R * CGFloat(sin(a))))
            }
            p.addLines(pts); p.closeSubpath()
        }
        return p
    }
}

/// The triangle "slash" from the AZ Creative logo: tip at top-trailing, base on the leading edge.
struct AZSwoosh: Shape {
    func path(in rect: CGRect) -> Path {
        // Proportions taken from the logo (340 × 204 px triangle).
        let w = min(rect.width, rect.height * 340 / 204), h = w * 204 / 340
        let r = CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + h * 0.534))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// Solid star outline (16 vertices) — good for badges.
struct StarBadge: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let R = min(rect.width, rect.height) / 2, r = R * 0.80
        var p = Path()
        for i in 0..<16 {
            let a = Double(i) * .pi / 8 - .pi / 2
            let rad = i % 2 == 0 ? R : r
            let pt = CGPoint(x: c.x + rad * CGFloat(cos(a)), y: c.y + rad * CGFloat(sin(a)))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }
}

/// Pointed (mihrab) arch.
struct MihrabArch: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let shoulder = rect.minY + w * 0.62
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: shoulder))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY + w * 0.12))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: shoulder), control: CGPoint(x: rect.maxX, y: rect.minY + w * 0.12))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        _ = h
        return p
    }
}

/// Static gradient border (no motion).
struct AccentBorder<S: InsettableShape>: View {
    let shape: S
    var width: CGFloat = 1.2
    var body: some View {
        shape.strokeBorder(LinearGradient(colors: [AZ.lime.opacity(0.8), AZ.violet.opacity(0.6), AZ.royal.opacity(0.25)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: width)
            .allowsHitTesting(false)
    }
}

/// Small Palestinian flag drawn with shapes.
struct PalestineFlag: View {
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                VStack(spacing: 0) {
                    Color.black
                    Color.white
                    Color(hex: 0x149954)
                }
                Path { p in
                    p.move(to: .zero)
                    p.addLine(to: CGPoint(x: g.size.width * 0.42, y: g.size.height / 2))
                    p.addLine(to: CGPoint(x: 0, y: g.size.height))
                    p.closeSubpath()
                }
                .fill(Color(hex: 0xE4312B))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// Bottom-rounded rectangle that hangs from the notch.
struct NotchShape: InsettableShape {
    var radius: CGFloat
    var topFlare: CGFloat = 6
    var insetAmount: CGFloat = 0

    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let rad = min(radius, r.height / 2, r.width / 2)
        var p = Path()
        // little outward flare at the top corners so it melts into the bezel
        p.move(to: CGPoint(x: r.minX - topFlare, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + topFlare), control: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - rad))
        p.addQuadCurve(to: CGPoint(x: r.minX + rad, y: r.maxY), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - rad, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY - rad), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + topFlare))
        p.addQuadCurve(to: CGPoint(x: r.maxX + topFlare, y: r.minY), control: CGPoint(x: r.maxX, y: r.minY))
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> NotchShape {
        var s = self; s.insetAmount += amount; return s
    }
}
