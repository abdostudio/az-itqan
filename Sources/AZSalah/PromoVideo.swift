import SwiftUI
import AppKit
import AVFoundation

// MARK: - Motion helpers

enum M {
    static func p(_ t: Double, _ start: Double, _ dur: Double) -> Double { min(1, max(0, (t - start) / dur)) }
    static func inOut(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
    static func out(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    static func back(_ x: Double) -> Double { let c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2) }
    /// 0→1 fade in at `a`, 1→0 fade out ending at `b`.
    static func window(_ t: Double, _ a: Double, _ b: Double, fade: Double = 0.45) -> Double {
        min(out(p(t, a, fade)), 1 - inOut(p(t, b - fade, fade)))
    }
    static func lerp(_ a: CGFloat, _ b: CGFloat, _ x: Double) -> CGFloat { a + (b - a) * CGFloat(x) }
}

/// Kinetic caption: words rise in one by one with a blur-to-sharp reveal.
struct KineticText: View {
    let text: String
    let t: Double          // local time since the caption started
    var size: CGFloat = 50
    var color: Color = .white
    var weight: Font.Weight = .bold
    var body: some View {
        let words = text.split(separator: " ").map(String.init)
        // Words from the one starting with "*" onward are the highlighted phrase.
        let hi = words.firstIndex { $0.hasPrefix("*") } ?? words.count
        HStack(spacing: size * 0.26) {
            ForEach(Array(words.enumerated()), id: \.offset) { i, w in
                let x = M.out(M.p(t, Double(i) * 0.07, 0.5))
                Text(w.replacingOccurrences(of: "*", with: ""))
                    .font(.system(size: size, weight: weight, design: .rounded))
                    .foregroundColor(i >= hi ? AZ.lime : color.opacity(0.82))
                    .opacity(x)
                    .offset(y: (1 - x) * 22)
                    .blur(radius: (1 - x) * 8)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Frame

@MainActor
struct PromoContext {
    let engine: PrayerEngine
    let notch = NotchModel()
    let lock = LockModel()
    let icon: NSImage?
}

struct PromoFrame: View {
    let t: Double
    let c: PromoContext

    var body: some View {
        Group {
            if PromoVideo.vertical {
                // 9:16 — same scenes, scaled into the middle, brand header on top, big two-line captions below.
                ZStack {
                    background
                    scenes.frame(width: 1920, height: 1080).offset(y: -70)
                    header
                    captions
                }
                .frame(width: 1080, height: 1920)
            } else {
                ZStack {
                    background
                    scenes
                    captions
                }
                .frame(width: 1920, height: 1080)
            }
        }
        .clipped()
        .environment(\.layoutDirection, .rightToLeft)
        .foregroundColor(.white)
    }

    private var scenes: some View {
        let v = PromoVideo.vertical
        func k(_ x: CGFloat) -> CGFloat { v ? x : 1 }
        return ZStack {
            scene1.scaleEffect(k(1.0)).opacity(M.window(t, 0, 6.2))
            scene2.scaleEffect(k(1.25)).opacity(M.window(t, 6, 10.3, fade: 0.25))
            macScenes.scaleEffect(k(0.69)).opacity(M.window(t, 10, 32.3, fade: 0.6))
            montage.scaleEffect(k(0.95)).opacity(M.window(t, 32, 42.3))
            floating.scaleEffect(k(0.69)).opacity(M.window(t, 42, 46.3))
            install.scaleEffect(k(0.98)).opacity(M.window(t, 46, 62.8))
            outro.scaleEffect(k(1.25)).opacity(M.window(t, 62.5, 70, fade: 0.6))
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            AZMark(letterColor: .white, slashColor: AZ.lime).frame(width: 66, height: 46)
            Text("AZ Itqan").font(.system(size: 44, weight: .heavy, design: .rounded))
        }
        .environment(\.layoutDirection, .leftToRight)
        .opacity(M.window(t, 10.3, 62.5, fade: 0.5))
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 190)
    }

    // Cinematic dark stage: near-black navy, soft royal glow and a few glossy light ribbons drifting slowly.
    // Big soft light, never a pattern.
    private var background: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x01030B), Color(hex: 0x030A22), Color(hex: 0x02050F)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [AZ.royal.opacity(0.32), .clear], center: UnitPoint(x: 0.5 + 0.08 * sin(t / 5), y: 0.42), startRadius: 0, endRadius: 820)
            ForEach(0..<3) { i in
                let k = Double(i)
                Ellipse()
                    .stroke(LinearGradient(colors: [.clear, AZ.royal, Color(hex: 0x7FA8FF), AZ.royal.opacity(0.6), .clear],
                                           startPoint: .leading, endPoint: .trailing),
                            lineWidth: CGFloat(54 - 16 * k))
                    .frame(width: 2300, height: 820)
                    .rotationEffect(.degrees(-22 + 8 * k + 4 * sin(t / 4.5 + k * 1.7)))
                    .offset(x: CGFloat(-380 + 60 * k + 40 * sin(t / 6 + k)), y: CGFloat(-360 + 50 * k))
                    .blur(radius: CGFloat(16 + 12 * k))
                    .opacity(0.5 - 0.12 * k)
            }
            RadialGradient(colors: [AZ.lime.opacity(0.06), .clear], center: UnitPoint(x: 0.82, y: 0.8), startRadius: 0, endRadius: 600)
            // vignette
            RadialGradient(colors: [.clear, .black.opacity(0.55)], center: .center, startRadius: 500, endRadius: 1200)
        }
    }

    // MARK: 1 — hook
    private var scene1: some View {
        let items: [(String, String)] = [("الفجر", "٤:٥٦"), ("الظهر", "١١:٤٢"), ("العصر", "٢:٣٦")]
        return VStack(spacing: 46) {
            HStack(spacing: 28) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, it in
                    let a = 0.9 + Double(i) * 0.55
                    let x = M.back(M.p(t, a, 0.6))
                    let strike = M.inOut(M.p(t, 3.2 + Double(i) * 0.35, 0.5))
                    VStack(spacing: 8) {
                        Text(it.0).font(.system(size: 34, weight: .semibold, design: .rounded)).foregroundColor(AZ.muted)
                        Text(it.1).font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                    }
                    .frame(width: 260, height: 190)
                    .background(RoundedRectangle(cornerRadius: 30).fill(Color.white.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                    .overlay(
                        Capsule().fill(Color(hex: 0xFF5A4E)).frame(height: 6)
                            .scaleEffect(x: strike, y: 1, anchor: .trailing).padding(.horizontal, 26)
                    )
                    .glass3D(yaw: 70 * (1 - x) - 14 + 8 * M.p(t, 0, 6), pitch: 0, gloss: M.p(t, a, 1.6) * 1.6 - 0.3, radius: 30)
                    .opacity(x > 0 ? 1 - 0.55 * strike : 0)
                    .scaleEffect(0.6 + 0.4 * x)
                }
            }
            .rotation3DEffect(.degrees(16), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .padding(.top, 60)
        }
        .offset(y: -40)
    }

    // MARK: 2 — logo reveal (strong): light streak → letters wipe up in 3D → slash slices in with a trail,
    // impact flash + shockwave + camera shake → light sweep → title tracks in.
    private var scene2: some View {
        let lt = t - 6
        let streak = M.p(lt, 0.0, 0.45)
        let wipe = M.out(M.p(lt, 0.25, 0.55))
        let tilt = 1 - M.out(M.p(lt, 0.25, 0.9))
        let slash = M.back(M.p(lt, 0.75, 0.38))
        let impact = M.p(lt, 1.05, 0.55)                 // 0 → 1 after the slash lands
        let flash = lt >= 1.05 ? max(0, 1 - impact * 2.2) : 0
        let shake = lt >= 1.05 ? (1 - impact) * 7 : 0
        let sweep = M.inOut(M.p(lt, 1.4, 0.9))
        let title = M.out(M.p(lt, 1.6, 0.7))
        let tag = M.out(M.p(lt, 2.15, 0.6))
        let zoom = 1.18 - 0.18 * M.out(M.p(lt, 0.2, 2.4)) + 0.06 * (lt >= 1.05 ? max(0, 1 - impact * 3) : 0)
        let markW: CGFloat = 380, markH: CGFloat = 266

        return ZStack {
            // impact glow behind the mark
            RadialGradient(colors: [AZ.lime.opacity(0.35 * flash + 0.10 * (lt >= 1.05 ? 1 : 0)), AZ.royal.opacity(0.25), .clear],
                           center: .center, startRadius: 0, endRadius: 520)
                .offset(y: -90)
            // shockwave ring
            Circle().strokeBorder(AZ.lime.opacity(0.7 * (1 - impact)), lineWidth: 3 * (1 - impact) + 0.5)
                .frame(width: 180 + 900 * impact, height: 180 + 900 * impact)
                .offset(y: -90)
                .opacity(lt >= 1.05 && impact < 1 ? 1 : 0)
            // opening light streak
            Capsule().fill(LinearGradient(colors: [.clear, AZ.lime, .white, AZ.lime, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(width: 900, height: 3)
                .offset(x: M.lerp(-1100, 1100, M.inOut(streak)), y: -90)
                .opacity(streak > 0 && streak < 1 ? 1 : 0)
                .blur(radius: 1)

            VStack(spacing: 30) {
                ZStack {
                    // letters: wipe up from the bottom, settling out of a 3D tilt
                    SVGShape(d: AZBrand.letters, viewBox: AZBrand.viewBox)
                        .fill(LinearGradient(colors: [.white, Color(hex: 0xC9D3F2)], startPoint: .top, endPoint: .bottom))
                        .mask(alignment: .bottom) { Rectangle().frame(height: markH * wipe) }
                        .rotation3DEffect(.degrees(28 * tilt), axis: (x: 1, y: -0.4, z: 0), perspective: 0.6)
                    // slash: motion trail ghosts + the real one
                    ForEach(1..<6) { i in
                        SVGShape(d: AZBrand.slash, viewBox: AZBrand.viewBox).fill(AZ.lime)
                            .offset(x: (1 - slash) * -420 - CGFloat(i) * 26 * CGFloat(1 - M.p(lt, 1.0, 0.25)),
                                    y: (1 - slash) * 160 + CGFloat(i) * 10 * CGFloat(1 - M.p(lt, 1.0, 0.25)))
                            .opacity(lt > 0.75 && lt < 1.3 ? 0.16 * Double(6 - i) / 5 : 0)
                    }
                    SVGShape(d: AZBrand.slash, viewBox: AZBrand.viewBox).fill(AZ.lime)
                        .offset(x: (1 - slash) * -420, y: (1 - slash) * 160)
                        .opacity(lt > 0.75 ? 1 : 0)
                        .shadow(color: AZ.lime.opacity(0.6 * flash + 0.25), radius: 18)
                    // light sweep across the whole mark
                    LinearGradient(colors: [.clear, .white.opacity(0.85), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 110)
                        .rotationEffect(.degrees(18))
                        .offset(x: M.lerp(-320, 320, sweep))
                        .mask(ZStack {
                            SVGShape(d: AZBrand.letters, viewBox: AZBrand.viewBox).fill(Color.white)
                            SVGShape(d: AZBrand.slash, viewBox: AZBrand.viewBox).fill(Color.white)
                        })
                        .opacity(sweep > 0 && sweep < 1 ? 1 : 0)
                        .blendMode(.screen)
                }
                .frame(width: markW, height: markH)
                .environment(\.layoutDirection, .leftToRight)

                // title: tracking in from wide + blur
                Text("AZ Itqan").font(.system(size: 96, weight: .heavy, design: .rounded))
                    .tracking(46 * (1 - title))
                    .blur(radius: 10 * (1 - title))
                    .opacity(title)
                    .environment(\.layoutDirection, .leftToRight)
                Text("إتقان في الشغل… وإتقان في الصلاة")
                    .font(.system(size: 40, weight: .semibold, design: .rounded)).foregroundColor(AZ.lime)
                    .opacity(tag).offset(y: (1 - tag) * 20).blur(radius: 6 * (1 - tag))
            }
            .scaleEffect(zoom)
            .offset(x: shake * sin(lt * 90), y: shake * cos(lt * 77))

            // full-frame white flash on impact
            Color.white.opacity(0.55 * flash)
        }
    }

    // MARK: 3–5 — on a MacBook screen
    private var macScenes: some View {
        // Camera: settle on the Mac, push in on the notch (11–19.6 s), pull back for the lock screen.
        let push = M.inOut(M.p(t, 11.0, 1.4)) * (1 - M.inOut(M.p(t, 19.6, 1.0)))
        let zoom = (0.8 + 0.03 * M.inOut(M.p(t, 20, 10))) * (1 + 1.35 * push)
        let enter = M.out(M.p(t, 10, 1.0))
        // 3D camera: swing in from a steep angle, flatten while reading the notch, then orbit slowly over the lock.
        let swing = M.inOut(M.p(t, 10, 1.8))
        let orbit = M.inOut(M.p(t, 20.4, 11))
        let flat = 1 - push
        let yaw = (34 - 20 * swing - 22 * orbit) * flat
        let pitch = (22 - 12 * swing - 4 * orbit) * flat
        return ZStack {
            // floor glow under the screen
            Ellipse().fill(RadialGradient(colors: [AZ.royal.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 700))
                .frame(width: 1500, height: 260).offset(y: 470).blur(radius: 30).opacity(flat)
            MacBookMockup {
                MacScreen(t: t, c: c)
                    .overlay(Sheen(gloss: M.p(t, 10.2, 2.2) * 1.8 - 0.4 + M.p(t, 20.4, 2) * 1.8))
            }
            .shadow(color: AZ.royal.opacity(0.4), radius: 80, y: 10)
            .shadow(color: .black.opacity(0.75), radius: 45, y: 45)
            .rotation3DEffect(.degrees(pitch), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
            .rotation3DEffect(.degrees(yaw), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
            .scaleEffect(zoom * 0.9 * (0.94 + 0.06 * enter) * (0.86 + 0.14 * swing), anchor: .top)
            .offset(y: -40 + 30 * push + (1 - enter) * 160 + 110 * (1 - swing) + 60 * M.out(M.p(t, 19.6, 1.5)))
        }
    }

    // MARK: 6 — feature montage: one live island morphing feature to feature, orbiting in 3D
    private var montage: some View {
        let changes: [Double] = [32, 34.5, 37, 39.5]
        let last = changes.last { $0 <= t } ?? 32
        let kick = 1 - M.out(M.p(t, last, 0.7))          // little swing on every morph
        let orbit = M.inOut(M.p(t, 31.7, 10.3))
        return LiveIsland(t: t, keys: IslandTimeline.montage, floating: true)
            .rotation3DEffect(.degrees(-18 + 36 * orbit + 10 * kick), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .rotation3DEffect(.degrees(12 - 4 * orbit + 4 * kick), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .scaleEffect(1.55)
            .frame(width: 1920, height: 700)
            .offset(y: -60)
    }

    // MARK: 7 — floating island, dragged and resized
    private var floating: some View {
        let lt = t - 42
        let move = M.inOut(M.p(lt, 0.6, 1.6))
        let grow = M.back(M.p(lt, 2.4, 0.8))
        let pos = CGPoint(x: M.lerp(0, 430, move), y: M.lerp(-250, 120, move) - 30 * sin(move * .pi))
        let orbit = M.inOut(M.p(lt, 0, 4.3))
        return ZStack {
            ZStack {
                MacWallpaper().frame(width: 1512, height: 982)
                FloatingIsland(c: c, scale: 1 + 0.4 * grow)
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 20)
                    .offset(x: pos.x, y: pos.y)
                Image(systemName: "cursorarrow").font(.system(size: 40, weight: .regular)).foregroundColor(.white)
                    .shadow(radius: 4)
                    .offset(x: pos.x + 20, y: pos.y + 28)
                    .opacity(lt < 2.3 ? 1 : 1 - M.p(lt, 2.3, 0.3))
            }
            .frame(width: 1512, height: 982)
            .overlay(Sheen(gloss: orbit * 1.6 - 0.3))
            .wrapMacBook()
            .shadow(color: AZ.royal.opacity(0.4), radius: 80, y: 10)
            .shadow(color: .black.opacity(0.75), radius: 45, y: 45)
            .rotation3DEffect(.degrees(14 - 4 * orbit), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
            .rotation3DEffect(.degrees(-20 + 26 * orbit), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
            .scaleEffect(0.74)
        }
    }

    // MARK: 8 — install guide (unknown developer)
    private var install: some View {
        let lt = t - 46
        let step = lt < 3 ? 0 : lt < 6 ? 1 : lt < 9.5 ? 2 : lt < 13 ? 3 : 4
        let layout = PromoVideo.vertical ? AnyLayout(VStackLayout(spacing: 50)) : AnyLayout(HStackLayout(alignment: .center, spacing: 70))
        return layout {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(0..<5) { i in
                    let titles = ["حمّلها من GitHub", "فك الضغط وانقلها لـ Applications", "لو ظهرت رسالة «مش قادر يتحقق»… عادي",
                                  "افتح Open Anyway من الإعدادات", "حدد موقعك… والمواعيد تتظبط"]
                    let on = i == step, done = i < step
                    HStack(spacing: 16) {
                        Text(AR.num(i + 1)).font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(on ? AZ.navy : done ? AZ.lime : AZ.muted)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(on ? AnyShapeStyle(AZ.accentGradient) : AnyShapeStyle(Color.white.opacity(0.06))))
                        Text(titles[i]).font(.system(size: 30, weight: on ? .bold : .medium, design: .rounded))
                            .foregroundColor(on ? .white : AZ.muted)
                    }
                    .opacity(M.out(M.p(lt, Double(i) * 0.15, 0.5)))
                }
            }
            .frame(width: 720, alignment: .leading)
            ZStack {
                InstallStepVisual(step: 0, lt: lt, icon: c.icon).opacity(M.window(lt, 0, 3.15, fade: 0.3))
                InstallStepVisual(step: 1, lt: lt - 3, icon: c.icon).opacity(M.window(lt, 3, 6.15, fade: 0.3))
                InstallStepVisual(step: 2, lt: lt - 6, icon: c.icon).opacity(M.window(lt, 6, 9.65, fade: 0.3))
                InstallStepVisual(step: 3, lt: lt - 9.5, icon: c.icon).opacity(M.window(lt, 9.5, 13.15, fade: 0.3))
                InstallStepVisual(step: 4, lt: lt - 13, icon: c.icon).opacity(M.window(lt, 13, 17, fade: 0.3))
            }
            .frame(width: 760, height: 560)
            // each step swings in, then drifts slowly
            .rotation3DEffect(.degrees(-16 + 8 * stepDrift(lt)), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .rotation3DEffect(.degrees(8), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .shadow(color: AZ.royal.opacity(0.4), radius: 50, y: 24)
        }
        .offset(y: -40)
    }

    /// 0 → 1 within each install step (with a quick swing at its start).
    private func stepDrift(_ lt: Double) -> Double {
        let starts: [Double] = [0, 3, 6, 9.5, 13, 17]
        guard let i = starts.lastIndex(where: { $0 <= lt }), i < starts.count - 1 else { return 1 }
        let x = M.p(lt, starts[i], starts[i + 1] - starts[i])
        return M.out(x) - 1.6 * (1 - M.out(M.p(lt, starts[i], 0.6)))
    }

    // MARK: 9 — outro
    private var outro: some View {
        let lt = t - 62.5
        let a = M.back(M.p(lt, 0.1, 0.7)), b = M.out(M.p(lt, 0.6, 0.6)), c2 = M.out(M.p(lt, 1.1, 0.6))
        return VStack(spacing: 26) {
            if let icon = c.icon {
                Image(nsImage: icon).resizable().frame(width: 190, height: 190)
                    .scaleEffect(0.7 + 0.3 * a).opacity(min(1, a))
            }
            Text("AZ Itqan").font(.system(size: 84, weight: .heavy, design: .rounded)).opacity(b)
                .environment(\.layoutDirection, .leftToRight)
            Text("حمّلها مجانًا").font(.system(size: 36, weight: .semibold, design: .rounded)).foregroundColor(AZ.lime).opacity(b)
            Text("github.com/abdostudio/az-itqan")
                .font(.system(size: 34, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 26).padding(.vertical, 12)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                .overlay(Capsule().strokeBorder(AZ.lime.opacity(0.5), lineWidth: 1.5))
                .opacity(c2).environment(\.layoutDirection, .leftToRight)
            HStack(spacing: 30) {
                HStack(spacing: 12) {
                    AZMark(letterColor: .white, slashColor: AZ.lime).frame(width: 64, height: 44)
                    Text("Abdelrahman Ahmed").font(.system(size: 26, weight: .semibold))
                }
                .environment(\.layoutDirection, .leftToRight)
                HStack(spacing: 10) {
                    PalestineFlag().frame(width: 42, height: 28)
                    Text("فلسطين في القلب").font(.system(size: 26, weight: .semibold, design: .rounded))
                }
            }
            .opacity(c2).padding(.top, 12)
        }
    }

    // MARK: captions (bottom)
    private var captions: some View {
        let list: [(Double, Double, String)] = [
            (0.3, 3.2, "إنت مصمم… *والوقت بيجري"), (3.2, 6.0, "والصلاة *بتفوت؟"),
            (10.8, 14.9, "ذِكر بيتغير *كل شوية"), (15.0, 17.7, "ومواعيد صلاتك *على النوتش"),
            (32.2, 34.4, "الأذكار *جوه النوتش"), (34.7, 36.9, "تقرير صلاتك *أسبوعي وشهري"),
            (37.2, 39.4, "الصدقة *وحاسبة الزكاة"), (39.7, 41.9, "رمضان · الورد · *فلسطين"),
            (18.2, 21.0, "قرّب الأذان؟ *بيفكّرك"), (21.0, 24.2, "وقت الأذان… *الشاشة بتقفل"),
            (24.2, 27.0, "لحد ما *تقوم تصلّي"), (27.2, 31.8, "ومش بتفتح غير لما *تقولها بصدق"),
            (42.3, 45.9, "حطه في أي مكان… *وبالحجم اللي يريّحك"),
            (46.3, 58.9, "أول مرة بس… *عادي لأنها مش من متجر أبل"),
            (59.0, 62.4, "وأهم حاجة… *حدد موقعك عشان المواعيد تبقى مظبوطة"),
        ]
        return VStack {
            Spacer()
            ZStack {
                ForEach(Array(list.enumerated()), id: \.offset) { _, c in
                    if t >= c.0 && t < c.1 {
                        captionText(c.2, t - c.0)
                            .padding(.horizontal, 34).padding(.vertical, 12)
                            .background(Capsule().fill(Color(hex: 0x040A20).opacity(0.55 * M.out(M.p(t - c.0, 0, 0.3)))))
                            .opacity(1 - M.inOut(M.p(t, c.1 - 0.3, 0.3)))
                            .overlay(alignment: .bottom) {
                                Capsule().fill(AZ.accentGradient).frame(width: 90 * M.out(M.p(t - c.0, 0.25, 0.6)), height: 5)
                                    .offset(y: 22)
                            }
                    }
                }
            }
            .padding(.bottom, PromoVideo.vertical ? 330 : 56)
        }
    }

    @ViewBuilder
    private func captionText(_ s: String, _ lt: Double) -> some View {
        if PromoVideo.vertical {
            let parts = s.components(separatedBy: "… ")
            VStack(spacing: 10) {
                ForEach(Array(parts.enumerated()), id: \.offset) { i, part in
                    KineticText(text: i < parts.count - 1 ? part + "…" : part, t: lt - Double(i) * 0.25, size: 60)
                }
            }
        } else {
            KineticText(text: s, t: lt)
        }
    }
}

// MARK: - 3D glass card: perspective tilt, glossy sheen sweep, lit edge, deep shadow + royal glow

extension View {
    func wrapMacBook() -> some View { MacBookMockup { self } }

    func glass3D(yaw: Double, pitch: Double, gloss: Double, radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .overlay(
                LinearGradient(stops: [.init(color: .clear, location: 0.0),
                                       .init(color: .white.opacity(0.07), location: 0.42),
                                       .init(color: .white.opacity(0.20), location: 0.5),
                                       .init(color: .white.opacity(0.05), location: 0.58),
                                       .init(color: .clear, location: 1.0)],
                               startPoint: UnitPoint(x: gloss - 0.7, y: 0), endPoint: UnitPoint(x: gloss + 0.7, y: 1))
                    .clipShape(shape).blendMode(.screen)
            )
            .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.45), Color(hex: 0x7FA8FF).opacity(0.35), .white.opacity(0.06)],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2))
            .shadow(color: AZ.royal.opacity(0.45), radius: 70, y: 10)
            .shadow(color: .black.opacity(0.7), radius: 40, y: 40)
            .rotation3DEffect(.degrees(pitch), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
            .rotation3DEffect(.degrees(yaw), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
    }
}

// MARK: - Mac screen mock with the real notch + lock

/// Clean brand wallpaper: deep royal blue with one soft light — keeps the notch the hero.
struct MacWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0B1F5C), Color(hex: 0x0A3BA8), Color(hex: 0x061230)], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color(hex: 0x5B8CFF).opacity(0.45), .clear], center: UnitPoint(x: 0.72, y: 0.78), startRadius: 0, endRadius: 760)
            RadialGradient(colors: [AZ.lime.opacity(0.10), .clear], center: UnitPoint(x: 0.2, y: 0.9), startRadius: 0, endRadius: 520)
        }
    }
}

/// Glossy light sweep (screen glass).
struct Sheen: View {
    let gloss: Double
    var body: some View {
        LinearGradient(stops: [.init(color: .clear, location: 0.0),
                               .init(color: .white.opacity(0.06), location: 0.42),
                               .init(color: .white.opacity(0.16), location: 0.5),
                               .init(color: .white.opacity(0.04), location: 0.58),
                               .init(color: .clear, location: 1.0)],
                       startPoint: UnitPoint(x: gloss - 0.7, y: 0), endPoint: UnitPoint(x: gloss + 0.7, y: 1))
            .blendMode(.screen)
    }
}

/// A clean MacBook Pro front mockup: black bezel, aluminium edge, and the base with its thumb notch.
struct MacBookMockup<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ c: () -> Content) { content = c() }
    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(width: 1512, height: 982)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 30)
                .background(UnevenRoundedRectangle(topLeadingRadius: 42, bottomLeadingRadius: 10, bottomTrailingRadius: 10, topTrailingRadius: 42, style: .continuous)
                    .fill(Color(hex: 0x09090B)))
                .overlay(UnevenRoundedRectangle(topLeadingRadius: 42, bottomLeadingRadius: 10, bottomTrailingRadius: 10, topTrailingRadius: 42, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Color(hex: 0xB8BEC8), Color(hex: 0x4A4F58), Color(hex: 0x2A2D33)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 5))
            // base / keyboard deck seen edge-on
            ZStack(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 40, bottomTrailingRadius: 40, topTrailingRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xE6E9EE), Color(hex: 0xA9AEB7), Color(hex: 0x5E626B)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 1800, height: 38)
                UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14)
                    .fill(LinearGradient(colors: [Color(hex: 0x6C717A), Color(hex: 0x9AA0A9)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 260, height: 13)
            }
        }
    }
}

struct MacScreen: View {
    let t: Double
    let c: PromoContext
    var body: some View {
        ZStack(alignment: .top) {
            MacWallpaper()
            // menu bar
            HStack(spacing: 22) {
                Image(systemName: "applelogo").font(.system(size: 15, weight: .semibold))
                Text("Illustrator").bold(); Text("File"); Text("Edit"); Text("Object"); Text("Type")
                Spacer()
                Image(systemName: "moon.stars"); Image(systemName: "wifi"); Text("2:34 PM")
            }
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.92))
            .padding(.horizontal, 22)
            .frame(height: 34)
            .background(Color.black.opacity(0.18))
            .environment(\.layoutDirection, .leftToRight)
            // the island, hand-animated (morphs between states with the app's spring)
            if t < 20.15 {
                LiveIsland(t: t, keys: IslandTimeline.mac, notchHeight: c.notch.notchHeight)
                    .frame(width: 1512, height: 982, alignment: .top)
            }
            // hardware notch
            UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10).fill(Color.black)
                .frame(width: c.notch.notchWidth, height: c.notch.notchHeight)
            // lock screen over everything
            if t >= 20.15 {
                // the island keeps growing until it IS the lock screen
                LiveIsland(t: t, keys: IslandTimeline.mac, notchHeight: c.notch.notchHeight)
                    .frame(width: 1512, height: 982, alignment: .top)
                    .opacity(1 - M.p(t, 20.9, 0.4))
                LockView(model: c.lock, primary: true, scale: 0.9) { _ in }
                    .frame(width: 1512, height: 982)
                    .opacity(M.out(M.p(t, 20.55, 0.6)))
                    .scaleEffect(1.04 - 0.04 * M.out(M.p(t, 20.55, 0.9)))
            }
        }
        .frame(width: 1512, height: 982)
    }
}

struct FloatingIsland: View {
    let c: PromoContext
    let scale: CGFloat
    var body: some View {
        NotchRootView(model: c.notch, engine: c.engine)
            .frame(width: 640, height: 400)
            .frame(width: 640, height: 140, alignment: .top)
    }
}

struct MontagePanel: View {
    let index: Int
    let c: PromoContext
    var body: some View {
        NotchRootView(model: c.notch, engine: c.engine)
            .frame(width: 640, height: 400)
    }
}

// MARK: - Install visuals

struct InstallStepVisual: View {
    let step: Int
    let lt: Double
    let icon: NSImage?

    var body: some View {
        switch step {
        case 0: githubCard
        case 1: dragToApps
        case 2: alertMock
        case 3: settingsMock
        default: locationCard
        }
    }

    /// First launch: pick a city or detect location — prayer times fill in.
    private var locationCard: some View {
        let press = M.p(lt, 0.6, 0.25)
        let reveal = M.out(M.p(lt, 1.2, 0.7))
        let pulse = 1 + 0.12 * sin(lt * 6)
        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "location.fill").font(.system(size: 30)).foregroundColor(AZ.lime)
                    .frame(width: 64, height: 64).background(Circle().fill(AZ.lime.opacity(0.14)))
                    .scaleEffect(reveal < 1 ? pulse : 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text("الموقع").font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("اختار مدينتك… أو خلّيها تتحدد تلقائي").font(.system(size: 18, design: .rounded)).foregroundColor(AZ.muted)
                }
            }
            HStack(spacing: 12) {
                Label("حدد موقعي تلقائي", systemImage: "location.circle.fill")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(press > 0 ? AZ.navy : .white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Capsule().fill(press > 0 ? AnyShapeStyle(AZ.accentGradient) : AnyShapeStyle(Color.white.opacity(0.1))))
                Text("أو").foregroundColor(AZ.muted).font(.system(size: 18))
                Text("القاهرة ▾").font(.system(size: 20, weight: .medium, design: .rounded))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(AZ.lime)
                    Text("القاهرة · الهيئة المصرية العامة للمساحة").font(.system(size: 19, weight: .semibold, design: .rounded))
                }
                HStack(spacing: 10) {
                    ForEach([("الفجر", "٤:٥٦"), ("الظهر", "١١:٤٢"), ("العصر", "٢:٣٦"), ("المغرب", "٤:٥٦"), ("العشاء", "٦:١٧")], id: \.0) { p in
                        VStack(spacing: 4) {
                            Text(p.0).font(.system(size: 15, design: .rounded)).foregroundColor(AZ.muted)
                            Text(p.1).font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                        }
                        .frame(width: 112, height: 78)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
                    }
                }
            }
            .opacity(reveal).offset(y: (1 - reveal) * 18)
        }
        .padding(30)
        .frame(width: 700, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 26).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
    }

    private var githubCard: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.down.circle.fill").font(.system(size: 90)).foregroundStyle(AZ.accentGradient)
                .offset(y: -10 * sin(lt * 3))
            Text("github.com/abdostudio/az-itqan").font(.system(size: 30, weight: .semibold, design: .monospaced))
                .environment(\.layoutDirection, .leftToRight)
            HStack(spacing: 12) {
                Image(systemName: "doc.zipper").font(.system(size: 26))
                Text("AZ-Itqan.zip").font(.system(size: 26, weight: .medium))
            }
            .padding(.horizontal, 22).padding(.vertical, 12)
            .background(Capsule().fill(Color.white.opacity(0.08)))
            .environment(\.layoutDirection, .leftToRight)
        }
    }

    private var dragToApps: some View {
        let x = M.inOut(M.p(lt, 0.4, 1.4))
        return ZStack {
            HStack(spacing: 260) {
                VStack(spacing: 10) {
                    Image(systemName: "folder.fill").font(.system(size: 110)).foregroundColor(Color(hex: 0x5AA9F8))
                    Text("Applications").font(.system(size: 22, weight: .medium))
                }
                Color.clear.frame(width: 150, height: 150)
            }
            .environment(\.layoutDirection, .leftToRight)
            if let icon {
                Image(nsImage: icon).resizable().frame(width: 150, height: 150)
                    .offset(x: M.lerp(205, -205, x), y: -30 * sin(x * .pi))
                    .scaleEffect(1 - 0.25 * x)
            }
        }
    }

    private var alertMock: some View {
        let pop = M.back(M.p(lt, 0.2, 0.5))
        return VStack(spacing: 16) {
            if let icon { Image(nsImage: icon).resizable().frame(width: 84, height: 84) }
            Text("“AZ Itqan” Not Opened").font(.system(size: 26, weight: .bold))
            Text("Apple could not verify “AZ Itqan” is free of malware that may harm your Mac or compromise your privacy.")
                .font(.system(size: 18)).multilineTextAlignment(.center).foregroundColor(.white.opacity(0.85))
            HStack(spacing: 12) {
                Text("Done").frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Color(hex: 0x0A84FF)))
                Text("Move to Trash").frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.12)))
            }
            .font(.system(size: 18, weight: .medium))
        }
        .padding(30)
        .frame(width: 440)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color(hex: 0x2C2C30)))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .environment(\.layoutDirection, .leftToRight)
        .scaleEffect(0.85 + 0.15 * pop).opacity(min(1, pop * 1.3))
    }

    private var settingsMock: some View {
        let cursor = M.inOut(M.p(lt, 0.5, 1.2))
        let click = M.p(lt, 1.8, 0.4)
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(["General", "Appearance", "Notifications", "Privacy & Security", "Desktop & Dock"], id: \.self) { s in
                    Text(s).font(.system(size: 17, weight: s.hasPrefix("Privacy") ? .semibold : .regular))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .frame(width: 200, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 7).fill(s.hasPrefix("Privacy") ? Color(hex: 0x0A84FF) : .clear))
                }
                Spacer()
            }
            .padding(16)
            .frame(width: 232)
            .background(Color(hex: 0x252528))
            VStack(alignment: .leading, spacing: 18) {
                Text("Privacy & Security").font(.system(size: 24, weight: .bold))
                Text("Security").font(.system(size: 17, weight: .semibold)).foregroundColor(.white.opacity(0.7))
                HStack {
                    Text("“AZ Itqan” was blocked to protect your Mac.").font(.system(size: 17))
                    Spacer()
                    Text("Open Anyway").font(.system(size: 17, weight: .semibold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(click > 0 ? AZ.lime.opacity(0.9) : Color.white.opacity(0.16)))
                        .foregroundColor(click > 0 ? AZ.navy : .white)
                        .overlay(
                            Circle().strokeBorder(AZ.lime, lineWidth: 3).frame(width: 90, height: 90)
                                .scaleEffect(0.4 + click).opacity(click > 0 ? 1 - click : 0)
                        )
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                Spacer()
            }
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0x1E1E21))
        }
        .frame(width: 760, height: 430)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .overlay(
            Image(systemName: "cursorarrow").font(.system(size: 34)).foregroundColor(.white).shadow(radius: 3)
                .offset(x: M.lerp(-120, 300, cursor), y: M.lerp(150, -20, cursor))
        )
        .environment(\.layoutDirection, .leftToRight)
    }
}

// MARK: - Renderer

@MainActor
enum PromoVideo {
    static let fps: Int32 = 30
    static let duration = 69.0
    static var vertical = false
    static var W: Int { vertical ? 1080 : 1920 }
    static var H: Int { vertical ? 1920 : 1080 }

    /// Sets the shared models to what the frame at time `t` should show.
    static func stage(_ t: Double, _ c: PromoContext) {
        let n = c.notch
        n.alert = nil; n.reader = nil; n.expanded = false; n.ambient = nil; n.tab = 0
        n.floating = false; n.scale = 1; n.notchWidth = 185; n.notchHeight = 34; n.hasNotch = true
        switch t {
        case 10..<12.2: break
        case 12.2..<14.6: n.ambient = .init(msg: Adhkar.dhikr[0], palestine: false)
        case 14.6..<16.0: n.ambient = .init(msg: Palestine.duas[0], palestine: true)
        case 16.0..<18.2: n.expanded = true
        case 18.2..<20.6: n.alert = .pre(.asr, Date().addingTimeInterval(9 * 60))
        case 32..<34.6:
            n.expanded = true; n.reader = .morning
            AdhkarSession.shared.start(.morning); AdhkarSession.shared.index = 6
            AdhkarSession.shared.counts = [0: 1, 1: 3, 2: 3, 3: 3, 4: 1, 5: 1]
        case 34.6..<37.1: n.expanded = true; n.tab = 1
        case 37.1..<39.6: n.expanded = true; n.tab = 2
        case 39.6..<42.2: n.expanded = true; n.tab = 0
        case 42..<46.5:
            n.floating = true; n.notchWidth = 22; n.notchHeight = 30; n.hasNotch = false
            n.ambient = .init(msg: Adhkar.dhikr[1], palestine: false)
            let grow = M.back(M.p(t - 42, 2.4, 0.8)); n.scale = 1 + 0.4 * grow
        default: break
        }
        let l = c.lock
        l.stage = t >= 27 ? .proof : .main
    }

    static func setupLock(_ c: PromoContext) {
        let l = c.lock
        let msg = Motivation.byPrayer[.asr]![0]
        l.prayer = .asr; l.adhanTime = c.engine.today[.asr] ?? Date(); l.shownAt = Date().addingTimeInterval(-200)
        l.headline = "الصلاة الوسطى"; l.message = msg; l.palestine = Palestine.items[1]
        l.snoozesLeft = 1; l.snoozeWindowEnd = Date().addingTimeInterval(300); l.appear = true
        l.doneAfter = 180; l.proofDua = LockModel.proofDuas[0]; l.streak = 7
        l.todayDone = [.fajr, .dhuhr]; l.tz = AppSettings.shared.location.timeZone
    }

    static func render(to dir: URL, previewOnly: Bool) {
        RenderMode.offscreen = true
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let iconURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/icon-1024.png")
        let ctx = PromoContext(engine: PrayerEngine(settings: AppSettings.shared), icon: NSImage(contentsOf: iconURL))
        setupLock(ctx)
        // sample report data (CLI defaults only)
        let tz = AppSettings.shared.location.timeZone
        for back in 0..<30 {
            let d = Calendar.current.date(byAdding: .day, value: -back, to: Date())!
            for p in Prayer.fard where (back * 3 + p.hashValue) % 11 != 0 { PrayerLog.mark(p, on: d, tz: tz, .prayed) }
        }

        func frame(_ t: Double) -> CGImage? {
            stage(t, ctx)
            let r = ImageRenderer(content: PromoFrame(t: t, c: ctx))
            r.scale = 1
            return r.cgImage
        }

        if previewOnly {
            for t in [12.0, 13.4, 15.2, 15.6, 16.5, 18.4, 19.6, 20.3, 20.7, 32.3, 33.0, 34.0, 34.6, 35.5, 38.0, 40.5, 2.0, 4.5, 11.5, 13.0, 15.0, 17.0, 19.5, 23.0, 29.5, 33.5, 36.0, 38.5, 41.0, 44.5, 47.5, 51.0, 54.0, 57.5, 61.0, 65.5] {
                guard let img = frame(t) else { continue }
                let rep = NSBitmapImageRep(cgImage: img)
                try? rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])?
                    .write(to: dir.appendingPathComponent(String(format: vertical ? "v%05.1f.jpg" : "f%05.1f.jpg", t)))
            }
            print("previews written")
            return
        }

        let silent = dir.appendingPathComponent(vertical ? "promo-silent-v.mp4" : "promo-silent.mp4")
        try? FileManager.default.removeItem(at: silent)
        guard let writer = try? AVAssetWriter(outputURL: silent, fileType: .mp4) else { return }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 14_000_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let total = Int(duration * Double(fps))
        for i in 0..<total {
            let t = Double(i) / Double(fps)
            autoreleasepool {
                guard let img = frame(t), let pool = adaptor.pixelBufferPool else { return }
                var pb: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
                guard let buf = pb else { return }
                CVPixelBufferLockBaseAddress(buf, [])
                let cg = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: W, height: H, bitsPerComponent: 8,
                                   bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                   bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
                cg?.draw(img, in: CGRect(x: 0, y: 0, width: W, height: H))
                CVPixelBufferUnlockBaseAddress(buf, [])
                while !input.isReadyForMoreMediaData { usleep(2000) }
                adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
            }
            if i % 150 == 0 { print("frame \(i)/\(total)") }
        }
        input.markAsFinished()
        let sem = DispatchSemaphore(value: 0)
        writer.finishWriting { sem.signal() }
        while sem.wait(timeout: .now() + 0.05) == .timedOut { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
        print("video written")
        addAdhan(video: silent, out: dir.appendingPathComponent(vertical ? "AZ-Itqan-promo-vertical.mp4" : "AZ-Itqan-promo.mp4"))
    }

    /// Lays the takbeer clip under the lock-screen moment (20.3 s → ~31 s) with a fade out.
    static func addAdhan(video: URL, out: URL) {
        let clip = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/adhan/v2-open.m4a")
        let comp = AVMutableComposition()
        let vAsset = AVURLAsset(url: video), aAsset = AVURLAsset(url: clip)
        guard let vSrc = vAsset.tracks(withMediaType: .video).first, let aSrc = aAsset.tracks(withMediaType: .audio).first,
              let vDst = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let aDst = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { return }
        let vDur = vAsset.duration
        try? vDst.insertTimeRange(CMTimeRange(start: .zero, duration: vDur), of: vSrc, at: .zero)
        let start = CMTime(seconds: 20.6, preferredTimescale: 600)
        let len = CMTime(seconds: 11.5, preferredTimescale: 600)
        try? aDst.insertTimeRange(CMTimeRange(start: .zero, duration: len), of: aSrc, at: start)
        let params = AVMutableAudioMixInputParameters(track: aDst)
        params.setVolumeRamp(fromStartVolume: 0.9, toEndVolume: 0, timeRange: CMTimeRange(start: start + len - CMTime(seconds: 2.5, preferredTimescale: 600), duration: CMTime(seconds: 2.5, preferredTimescale: 600)))
        let mix = AVMutableAudioMix(); mix.inputParameters = [params]
        try? FileManager.default.removeItem(at: out)
        guard let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else { return }
        ex.outputURL = out; ex.outputFileType = .mp4; ex.audioMix = mix
        let sem = DispatchSemaphore(value: 0)
        ex.exportAsynchronously { sem.signal() }
        while sem.wait(timeout: .now() + 0.05) == .timedOut { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
        print(ex.status == .completed ? "final: \(out.path)" : "audio mux failed: \(String(describing: ex.error))")
    }
}
