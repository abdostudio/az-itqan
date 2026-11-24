import SwiftUI
import AppKit

/// Story cards (1080×1920) to share the notch content on Instagram / WhatsApp status.
struct StoryItem {
    enum Kind { case dhikr, dua, ayah, tafsir, hadith }
    let kind: Kind
    let text: String
    let source: String
    var note: String? = nil        // tafsir text or a short virtue line
    var noteSource: String? = nil
    var notch: String = ""

    var title: String {
        switch kind {
        case .dhikr: return tr("ذِكر")
        case .dua: return tr("دعاء")
        case .ayah: return tr("آية")
        case .tafsir: return tr("آية وتفسير")
        case .hadith: return tr("حديث")
        }
    }
    var symbol: String {
        switch kind {
        case .dhikr: return "sparkles"
        case .dua: return "hands.sparkles.fill"
        case .ayah: return "book.closed.fill"
        case .tafsir: return "text.book.closed.fill"
        case .hadith: return "quote.bubble.fill"
        }
    }
    var tint: Color {
        switch kind {
        case .dhikr: return AZ.lime
        case .dua: return AZ.violet
        case .ayah: return AZ.gold
        case .tafsir: return Color(hex: 0x6FE3C9)
        case .hadith: return Color(hex: 0x7CC4FF)
        }
    }
    var isQuran: Bool { kind == .ayah || kind == .tafsir }
}

struct StoryCard: View {
    let item: StoryItem
    var post = false            // 4:5 feed post (1080×1350) instead of a 9:16 story
    private var fit: CGFloat { let n = item.text.count + (item.note?.count ?? 0) / 3; return n > 170 ? 0.58 : n > 120 ? 0.66 : n > 80 ? 0.78 : n > 50 ? 0.9 : 1 }
    private var noteFit: CGFloat { let n = item.note?.count ?? 0; return n > 260 ? 0.78 : n > 180 ? 0.88 : 1 }
    var body: some View {
        ZStack {
            // Cinematic stage: near-black navy, big soft lights and glossy ribbons in the card colour (never a pattern).
            LinearGradient(colors: [Color(hex: 0x01030B), Color(hex: 0x041038), Color(hex: 0x02050F)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [AZ.royal.opacity(0.55), .clear], center: .init(x: 0.25, y: 0.18), startRadius: 0, endRadius: 520)
            RadialGradient(colors: [item.tint.opacity(0.30), .clear], center: .init(x: 0.8, y: 0.78), startRadius: 0, endRadius: 480)
            ForEach(0..<3) { i in
                let k = Double(i)
                Ellipse()
                    .stroke(LinearGradient(colors: [.clear, AZ.royal, item.tint.opacity(0.9), Color(hex: 0x7FA8FF).opacity(0.7), .clear],
                                           startPoint: .leading, endPoint: .trailing), lineWidth: CGFloat(30 - 8 * k))
                    .frame(width: 1200, height: 520)
                    .rotationEffect(.degrees(-28 + 9 * k))
                    .offset(x: CGFloat(-120 + 40 * k), y: CGFloat(-300 + 70 * k))
                    .blur(radius: CGFloat(10 + 8 * k))
                    .opacity(0.55 - 0.13 * k)
            }
            IslamicLattice(color: item.tint)
                .mask(RadialGradient(colors: [.clear, .clear, .black], center: .init(x: 0.5, y: 0.5), startRadius: 0, endRadius: 560))
            RadialGradient(colors: [.clear, .black.opacity(0.55)], center: .center, startRadius: 280, endRadius: 720)

            VStack(spacing: 0) {
                // The notch, as it sits on the Mac.
                HStack(spacing: 7) {
                    Circle().fill(item.tint).frame(width: 6, height: 6)
                    Text(item.notch).font(AZFont.ui(12.5, .semibold)).foregroundColor(.white.opacity(0.88))
                        .lineLimit(1).fixedSize()
                }
                .padding(.horizontal, 20).frame(minWidth: 150).frame(height: 34)
                .background(Capsule().fill(Color.black))
                    .overlay(alignment: .bottom) {
                        Capsule().fill(item.tint).frame(width: 64, height: 3).offset(y: 7)
                    }
                    .shadow(color: item.tint.opacity(0.5), radius: 18)
                    .padding(.top, post ? 34 : 70)

                Spacer()

                // Expanded island holding the card.
                VStack(spacing: 22) {
                    HStack(spacing: 8) {
                        Image(systemName: item.symbol).font(.system(size: 14, weight: .semibold))
                        Text(item.title).font(AZFont.ui(15, .bold))
                    }
                    .foregroundColor(item.tint)
                    .padding(.horizontal, 16).padding(.vertical, 7)
                    .background(Capsule().fill(item.tint.opacity(0.12)))

                    Text(item.isQuran ? "﴿ \(item.text) ﴾" : item.text)
                        .font(item.isQuran ? AZFont.quran((item.kind == .tafsir ? 34 : 38) * fit) : AZFont.ui(31 * fit, .semibold))
                        .lineSpacing(item.isQuran ? 12 : 10)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    if !item.source.isEmpty { Text(item.source).font(AZFont.ui(15, .medium)).foregroundColor(item.tint.opacity(0.9)) }

                    if let note = item.note {
                        Rectangle().fill(Color.white.opacity(0.12)).frame(width: 60, height: 1)
                        Text(note).font(AZFont.ui((item.kind == .tafsir ? 19 : 18) * noteFit)).lineSpacing(6)
                            .multilineTextAlignment(.center).foregroundColor(AZ.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        if let ns = item.noteSource {
                            Text(ns).font(AZFont.ui(13, .medium)).foregroundColor(AZ.muted.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 34).padding(.vertical, 40)
                .frame(width: 452)
                .background(
                    RoundedRectangle(cornerRadius: 44, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0x0E1534), Color.black.opacity(0.96), Color(hex: 0x05081A)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .overlay(alignment: .top) {
                    // lit top edge in the card colour
                    Capsule().fill(LinearGradient(colors: [.clear, item.tint, .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 220, height: 2).blur(radius: 0.5)
                }
                .glass3D(yaw: -7, pitch: 9, gloss: 0.35, radius: 44)
                .shadow(color: item.tint.opacity(0.35), radius: 60, y: 20)

                Spacer()

                // Signature
                HStack(spacing: 10) {
                    AZMark(letterColor: .white, slashColor: AZ.royal).frame(height: 22)
                    Text(verbatim: "AZ Itqan").font(AZFont.ui(17, .semibold)).foregroundColor(.white.opacity(0.85))
                        .environment(\.layoutDirection, .leftToRight)
                }
                .environment(\.layoutDirection, .leftToRight)
                Text(tr("إتقان في الشغل… وإتقان في الصلاة")).font(AZFont.ui(13)).foregroundColor(AZ.muted)
                    .padding(.top, 8).padding(.bottom, post ? 28 : 64)
            }
        }
        .frame(width: 540, height: post ? 675 : 960)
        .clipped()
        .environment(\.layoutDirection, Lang.dir)
    }
}

enum StoryCards {
    static let samples: [StoryItem] = [
        StoryItem(kind: .dhikr, text: "سبحان الله وبحمده\nسبحان الله العظيم", source: "",
                  note: "«كلمتان خفيفتان على اللسان، ثقيلتان في الميزان، حبيبتان إلى الرحمن»", noteSource: "متفق عليه", notch: "أذكار الصباح"),
        StoryItem(kind: .dua, text: "اللهم أعنّي على ذكرك\nوشكرك وحسن عبادتك", source: "رواه أبو داود والنسائي", notch: "العصر بعد ٢٣ د"),
        StoryItem(kind: .ayah, text: "وَاسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ ۚ وَإِنَّهَا لَكَبِيرَةٌ إِلَّا عَلَى الْخَاشِعِينَ",
                  source: "سورة البقرة — آية ٤٥", notch: Hijri.string(Date())),
        StoryItem(kind: .tafsir, text: "الَّذِينَ آمَنُوا وَتَطْمَئِنُّ قُلُوبُهُم بِذِكْرِ اللَّهِ ۗ أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ",
                  source: "سورة الرعد — آية ٢٨",
                  note: "المؤمنون تسكن قلوبهم وتأنس بذكر الله وطاعته، فبذكر الله وحده تطمئن القلوب.",
                  noteSource: "التفسير الميسّر (نص تجريبي)", notch: "تدبّر آية"),
        StoryItem(kind: .hadith, text: "«أحبُّ الأعمال إلى الله\nأدومُها وإن قلّ»", source: "متفق عليه", notch: "صلّيت ٥ من ٥ النهارده"),
    ]

    @MainActor static func render(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (i, item) in samples.enumerated() {
            let r = ImageRenderer(content: StoryCard(item: item))
            r.scale = 2
            guard let img = r.nsImage, let tiff = img.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { continue }
            let url = dir.appendingPathComponent("story-\(i + 1).png")
            try? png.write(to: url)
            print("wrote \(url.lastPathComponent)")
        }
        // Real pool picks, a post-size card and the share window.
        func save<V: View>(_ name: String, _ v: V) {
            let r = ImageRenderer(content: v.environment(\.layoutDirection, Lang.dir)); r.scale = 2
            if let img = r.nsImage, let d = StoryExport.png(img) { try? d.write(to: dir.appendingPathComponent(name)); print("wrote \(name)") }
        }
        for k in StoryPool.kinds {
            print(k, StoryPool.items(k).count)
            var it = StoryPool.pick(only: k, engine: nil); it.notch = StoryNotchLabel.hijri.text(for: it, engine: nil)
            save("pool-\(k).png", StoryCard(item: it))
        }
        var it = StoryPool.pick(only: .ayah, engine: nil); it.notch = it.title
        save("post.png", StoryCard(item: it, post: true))
        RenderMode.offscreen = true
        save("share-window.png", StoryShareView(model: StoryShareModel(engine: nil)))
    }
}

/// Fine line lattice of interlaced octagons and squares (mashrabiya feel), drawn once — no fill, low contrast.
struct IslamicLattice: View {
    var color: Color
    var cell: CGFloat = 76
    var body: some View {
        Canvas { ctx, size in
            let a = cell, s = a / (1 + sqrt(2)), e = (a - s) / 2
            var lines = Path(), rosette = Path()
            var y: CGFloat = -a
            while y < size.height + a {
                var x: CGFloat = -a
                while x < size.width + a {
                    // octagon
                    let o = [CGPoint(x: x + e, y: y), CGPoint(x: x + e + s, y: y), CGPoint(x: x + a, y: y + e),
                             CGPoint(x: x + a, y: y + e + s), CGPoint(x: x + e + s, y: y + a), CGPoint(x: x + e, y: y + a),
                             CGPoint(x: x, y: y + e + s), CGPoint(x: x, y: y + e)]
                    lines.addLines(o); lines.closeSubpath()
                    // interlace: two squares through the octagon (8-fold rosette made of lines)
                    let c = CGPoint(x: x + a / 2, y: y + a / 2), r = a * 0.36
                    for k in 0..<2 {
                        var pts: [CGPoint] = []
                        for i in 0..<4 {
                            let t = Double(k) * .pi / 4 + Double(i) * .pi / 2
                            pts.append(CGPoint(x: c.x + r * CGFloat(cos(t)), y: c.y + r * CGFloat(sin(t))))
                        }
                        rosette.addLines(pts); rosette.closeSubpath()
                    }
                    rosette.addEllipse(in: CGRect(x: c.x - a * 0.12, y: c.y - a * 0.12, width: a * 0.24, height: a * 0.24))
                    x += a
                }
                y += a
            }
            ctx.stroke(lines, with: .color(.white.opacity(0.13)), lineWidth: 0.9)
            ctx.stroke(rosette, with: .color(color.opacity(0.26)), lineWidth: 0.9)
        }
    }
}

/// Dev preview: the fasting line and the evening reminder across the white days (`--fasting-preview <dir>`).
enum FastingPreview {
    @MainActor static func render(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let settings = AppSettings.shared
        let cal = Calendar(identifier: .gregorian)
        // find the 12th of the current Hijri month
        var start = Date()
        for off in -20...20 {
            let d = cal.date(byAdding: .day, value: off, to: Date())!
            let h = Hijri.components(d, adjust: settings.hijriAdjust)
            if h.day == 12 { start = d; break }
        }
        let days = (0..<4).map { cal.date(byAdding: .day, value: $0, to: start)! }
        let board = VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, d in
                let h = Hijri.components(d, adjust: settings.hijriAdjust)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        Text(AR.weekday(d, tz: .current)); Text(AR.num(h.day)); Text(Hijri.monthNames[h.month - 1])
                    }.font(AZFont.ui(13, .bold)).foregroundColor(AZ.lime)
                    HStack(spacing: 10) {
                        Text(tr("في النوتش:")).font(AZFont.ui(11)).foregroundColor(AZ.muted).frame(width: 70, alignment: .leading)
                        if let s = Fasting.status(on: d, adjust: settings.hijriAdjust) { FastingChip(status: s) }
                        else { Text("—").foregroundColor(AZ.muted) }
                    }
                    HStack(alignment: .top, spacing: 10) {
                        Text(tr("بعد المغرب:")).font(AZFont.ui(11)).foregroundColor(AZ.muted).frame(width: 70, alignment: .leading)
                        if let p = Fasting.tomorrowPhrase(after: d, adjust: settings.hijriAdjust) {
                            let m: NotchModel = { let m = NotchModel(); m.notchWidth = 185; m.notchHeight = 32
                                m.alert = .fasting([p], ""); return m }()
                            FastingSlim(model: m, text: m.fastingText ?? "")
                                .frame(width: m.fastingSize.width, height: m.fastingSize.height)
                                .background(UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14).fill(Color.black))
                                .overlay(alignment: .top) { Capsule().fill(Color(white: 0.12)).frame(width: 185, height: 30).padding(.top, 1) }
                        } else {
                            Text(tr("مفيش تذكير (الأيام البيض خلصت)")).font(AZFont.ui(11.5)).foregroundColor(AZ.muted)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
            }
        }
        .padding(22)
        .frame(width: 620)
        .background(AZ.deepGradient)
        .foregroundColor(.white)
        .environment(\.layoutDirection, Lang.dir)
        let r = ImageRenderer(content: board); r.scale = 2
        if let img = r.nsImage, let d = StoryExport.png(img) {
            try? d.write(to: dir.appendingPathComponent("fasting-white-days.png")); print("wrote")
        }
    }
}
