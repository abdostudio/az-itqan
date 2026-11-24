import SwiftUI

/// A hand-animated version of the AZ Itqan island for the promo video.
/// Every frame is a pure function of time: the shape morphs between states with the app's spring bounce,
/// and the content inside actually moves (dhikr swapping, countdown ticking, rings filling, bars growing…).

struct IslandKey {
    enum Kind { case notch, strip, expanded, preAlert, adhan, full, reader, report, giving, ramadan }
    let at: Double
    let size: CGSize
    let radius: CGFloat
    let kind: Kind
    var bounce = true
    init(_ at: Double, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ kind: Kind, bounce: Bool = true) {
        self.at = at; size = CGSize(width: w, height: h); radius = r; self.kind = kind; self.bounce = bounce
    }
}

enum IslandTimeline {
    /// On the MacBook (10 – 21 s): idle strip → open → collapse → pre-alert → adhan → grows into the lock screen.
    static let mac: [IslandKey] = [
        .init(10.0, 185, 34, 10, .notch),
        .init(11.0, 400, 66, 18, .strip),
        .init(15.0, 620, 272, 30, .expanded),
        .init(17.7, 400, 66, 18, .strip),
        .init(18.2, 560, 132, 28, .preAlert),
        .init(19.35, 640, 176, 34, .adhan),
        .init(20.15, 1512, 982, 22, .full, bounce: false),
    ]
    /// Feature montage (32 – 42 s), floating on its own.
    static let montage: [IslandKey] = [
        .init(31.7, 260, 56, 28, .notch),
        .init(32.0, 640, 262, 34, .reader),
        .init(34.5, 640, 270, 34, .report),
        .init(37.0, 660, 210, 34, .giving),
        .init(39.5, 640, 196, 34, .ramadan),
    ]
}

private func spring(_ x: Double) -> Double { x >= 1 ? 1 : 1 - exp(-5.2 * x) * cos(10.5 * x) }

struct LiveIsland: View {
    let t: Double
    let keys: [IslandKey]
    var floating = false
    var notchHeight: CGFloat = 34

    var body: some View {
        let i = keys.lastIndex { $0.at <= t } ?? 0
        let cur = keys[i], prev = keys[max(0, i - 1)]
        let x = M.p(t, cur.at, cur.bounce ? 0.85 : 0.7)
        let e = cur.bounce ? spring(x) : M.inOut(x)
        let w = M.lerp(prev.size.width, cur.size.width, e)
        let h = max(notchHeight, M.lerp(prev.size.height, cur.size.height, e))
        let r = max(6, M.lerp(prev.radius, cur.radius, min(1, e)))
        let a = M.out(M.p(t, cur.at + 0.12, 0.45))
        let outP = M.p(t, cur.at, 0.16)
        let big = min(1, Double(h) / 200)

        ZStack(alignment: .top) {
            LinearGradient(stops: [.init(color: .black, location: 0),
                                   .init(color: .black, location: floating ? 0 : min(0.5, Double(notchHeight / h))),
                                   .init(color: AZ.navy, location: 0.62),
                                   .init(color: AZ.indigo.opacity(0.85), location: 1)],
                           startPoint: .top, endPoint: .bottom)
            if i > 0 && outP < 1 {
                content(prev.kind, t - prev.at)
                    .frame(width: prev.size.width, height: prev.size.height, alignment: .top)
                    .opacity(1 - outP).blur(radius: 6 * outP)
            }
            content(cur.kind, t - cur.at)
                .frame(width: cur.size.width, height: cur.size.height, alignment: .top)
                .opacity(a).blur(radius: 9 * (1 - a))
                .scaleEffect(0.94 + 0.06 * a, anchor: .top)
        }
        .frame(width: w, height: h, alignment: .top)
        .clipShape(shape(r))
        .overlay(shape(r).stroke(LinearGradient(colors: [.white.opacity(0.0), Color(hex: 0x7FA8FF).opacity(0.35 * big), AZ.lime.opacity(0.25 * big)],
                                                startPoint: .top, endPoint: .bottom), lineWidth: 1.5))
        .shadow(color: AZ.royal.opacity(0.55 * big), radius: 40, y: 14)
        .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
    }

    private func shape(_ r: CGFloat) -> AnyShape {
        floating ? AnyShape(RoundedRectangle(cornerRadius: r, style: .continuous)) : AnyShape(NotchShape(radius: r))
    }

    @ViewBuilder
    private func content(_ k: IslandKey.Kind, _ lt: Double) -> some View {
        switch k {
        case .notch, .full: Color.clear
        case .strip: strip(lt)
        case .expanded: expanded(lt)
        case .preAlert: preAlert(lt)
        case .adhan: adhan(lt)
        case .reader: reader(lt)
        case .report: report(lt)
        case .giving: giving(lt)
        case .ramadan: ramadan(lt)
        }
    }

    // MARK: states

    private func strip(_ lt: Double) -> some View {
        let lines = ["سبحان الله وبحمده… سبحان الله العظيم", "لا إله إلا الله وحده لا شريك له", "اللهم انصر أهلنا في فلسطين"]
        let idx = min(lines.count - 1, Int(lt / 1.3))
        let lx = M.out(M.p(lt - Double(idx) * 1.3, 0, 0.45))
        return HStack(spacing: 8) {
            if idx == 2 { PalestineFlag().frame(width: 20, height: 13) }
            Text(lines[idx]).font(AZFont.ui(15, .semibold)).foregroundColor(.white.opacity(0.94))
        }
        .opacity(lx).offset(y: (1 - lx) * 10).blur(radius: (1 - lx) * 5)
        .padding(.top, notchHeight + 6)
    }

    private func expanded(_ lt: Double) -> some View {
        let secs = max(0, 765 - Int(lt * 9))
        let prayers = [("الفجر", "٤:٥٦"), ("الظهر", "١١:٤٢"), ("العصر", "٢:٣٦"), ("المغرب", "٥:٠٢"), ("العشاء", "٦:٢٢")]
        let ring = 0.62 + 0.08 * M.out(M.p(lt, 0.1, 1.6))
        return VStack(spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("الصلاة الجاية").font(AZFont.ui(13)).foregroundColor(AZ.muted)
                    Text("العصر").font(AZFont.ui(34, .heavy))
                    Text("٢:٣٦ م · الأربعاء").font(AZFont.ui(13)).foregroundColor(AZ.muted)
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 7)
                    Circle().trim(from: 0, to: ring)
                        .stroke(LinearGradient(colors: [AZ.violet, AZ.lime], startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(AR.clock(TimeInterval(secs))).font(AZFont.ui(19, .bold).monospacedDigit()).foregroundColor(AZ.lime)
                        Text("باقي").font(AZFont.ui(11)).foregroundColor(AZ.muted)
                    }
                }
                .frame(width: 104, height: 104)
            }
            HStack(spacing: 8) {
                ForEach(0..<5) { j in
                    let c = M.back(M.p(lt, 0.15 + Double(j) * 0.07, 0.45))
                    let next = j == 2
                    VStack(spacing: 3) {
                        Text(prayers[j].0).font(AZFont.ui(12, .semibold)).foregroundColor(next ? .white : AZ.muted)
                        Text(prayers[j].1).font(AZFont.ui(15, .bold).monospacedDigit()).foregroundColor(next ? AZ.lime : .white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 12).fill(next ? AnyShapeStyle(LinearGradient(colors: [AZ.royal.opacity(0.7), AZ.indigo.opacity(0.4)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.white.opacity(0.05))))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AZ.lime.opacity(next ? 0.35 + 0.3 * sin(lt * 5) : 0), lineWidth: 1.2))
                    .opacity(min(1, c)).offset(y: (1 - c) * 18)
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, notchHeight + 14)
    }

    private func preAlert(_ lt: Double) -> some View {
        let pulse = (lt * 1.2).truncatingRemainder(dividingBy: 1)
        return HStack(spacing: 16) {
            ZStack {
                Circle().stroke(AZ.lime.opacity(0.6 * (1 - pulse)), lineWidth: 2).frame(width: 46 + 34 * pulse, height: 46 + 34 * pulse)
                Circle().fill(AZ.lime.opacity(0.14)).frame(width: 46, height: 46)
                Image(systemName: "bell.fill").font(.system(size: 20)).foregroundColor(AZ.lime)
                    .rotationEffect(.degrees(16 * sin(lt * 18) * max(0, 1 - lt / 1.2)), anchor: .top)
            }
            .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text("قرّب ميعاد العصر").font(AZFont.ui(16, .bold)).foregroundColor(AZ.lime)
                Text("الأذان بعد \(AR.num(max(1, 10 - Int(lt * 2)))) د — احفظ شغلك").font(AZFont.ui(18, .semibold))
                Text("العصر ٢:٣٦ م").font(AZFont.ui(13)).foregroundColor(AZ.muted)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, notchHeight + 6)
    }

    private func adhan(_ lt: Double) -> some View {
        let glow = 0.5 + 0.5 * sin(lt * 6)
        return ZStack {
            ForEach(0..<2) { j in
                let p = (lt * 0.9 + Double(j) * 0.5).truncatingRemainder(dividingBy: 1)
                Capsule().stroke(AZ.lime.opacity(0.45 * (1 - p)), lineWidth: 1.5)
                    .frame(width: 160 + 300 * p, height: 50 + 60 * p)
            }
            VStack(spacing: 4) {
                Text("حان الآن موعد صلاة").font(AZFont.ui(16, .semibold)).foregroundColor(AZ.muted)
                Text("العصر").font(AZFont.ui(46, .heavy)).foregroundColor(AZ.lime)
                    .shadow(color: AZ.lime.opacity(0.5 * glow), radius: 18)
                Text("حيّ على الصلاة").font(AZFont.ui(14)).foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.top, notchHeight + 4)
    }

    private func header(_ icon: String, _ color: Color, _ title: String, _ trailing: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(color)
            Text(title).font(AZFont.ui(20, .bold))
            Spacer()
            Text(trailing).font(AZFont.ui(13, .semibold)).foregroundColor(AZ.muted)
                .padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(Color.white.opacity(0.07)))
        }
    }

    private func reader(_ lt: Double) -> some View {
        let count = min(3, 1 + Int(max(0, lt - 0.5) / 0.55))
        let tapT = (max(0, lt - 0.5)).truncatingRemainder(dividingBy: 0.55)
        let bump = count < 3 || lt < 0.5 + 0.55 * 2 + 0.3 ? 1 + 0.12 * max(0, 1 - tapT / 0.2) : 1
        let ring = M.lerp(CGFloat(count - 1) / 3, CGFloat(count) / 3, M.out(min(1, tapT / 0.25)))
        let done = count == 3 && lt > 0.5 + 0.55 * 2 + 0.25
        return VStack(spacing: 16) {
            header("sun.horizon.fill", AZ.gold, "أذكار الصباح", "\(AR.num(6)) من \(AR.num(22))")
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(AZ.accentGradient).frame(width: g.size.width * (0.23 + 0.05 * M.out(M.p(lt, 0.2, 2))))
                }
            }
            .frame(height: 6)
            Text("رضيت بالله ربًّا، وبالإسلام دينًا، وبمحمد ﷺ نبيًّا")
                .font(AZFont.ui(24, .semibold)).multilineTextAlignment(.center).frame(maxWidth: .infinity)
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 5)
                Circle().trim(from: 0, to: ring).stroke(AZ.lime, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                Text(done ? "✓" : "\(AR.num(count))/\(AR.num(3))").font(AZFont.ui(18, .bold)).foregroundColor(AZ.lime)
            }
            .frame(width: 66, height: 66)
            .scaleEffect(bump)
        }
        .padding(.horizontal, 30).padding(.top, 26)
    }

    private func report(_ lt: Double) -> some View {
        let vals: [CGFloat] = [5, 5, 4, 5, 5, 3, 5]
        let days = ["سبت", "أحد", "اتنين", "تلات", "أربع", "خميس", "جمعة"]
        let total = Int(32 * M.out(M.p(lt, 0.3, 1.4)))
        return VStack(spacing: 18) {
            header("chart.bar.fill", AZ.lime, "تقريرك الأسبوعي", "الأسبوع ده")
            HStack(alignment: .bottom, spacing: 26) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AR.num(total)).font(AZFont.ui(64, .heavy).monospacedDigit()).foregroundColor(AZ.lime)
                    Text("من \(AR.num(35)) صلاة في وقتها").font(AZFont.ui(14)).foregroundColor(AZ.muted)
                    Text("ما شاء الله… كمّل").font(AZFont.ui(15, .semibold)).padding(.top, 6)
                }
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(0..<7) { j in
                        let g = M.back(M.p(lt, 0.25 + Double(j) * 0.08, 0.55))
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(LinearGradient(colors: vals[j] == 5 ? [AZ.lime, Color(hex: 0x9CF06B)] : [AZ.violet, AZ.royal], startPoint: .top, endPoint: .bottom))
                                .frame(width: 26, height: max(2, 24 * vals[j] * CGFloat(g)))
                            Text(days[j]).font(AZFont.ui(11)).foregroundColor(AZ.muted)
                        }
                    }
                }
                .frame(height: 150, alignment: .bottom)
            }
        }
        .padding(.horizontal, 30).padding(.top, 26)
    }

    private func giving(_ lt: Double) -> some View {
        let amount = Int(25000 * M.out(M.p(lt, 0.3, 1.2)))
        let zakat = amount / 40
        let streak = Int(12 * M.out(M.p(lt, 0.2, 1.2)))
        return VStack(spacing: 16) {
            header("hands.and.sparkles.fill", AZ.gold, "العطاء", "صدقة وزكاة")
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("صدقة النهارده").font(AZFont.ui(15, .semibold)).foregroundColor(AZ.muted)
                    Text("\(AR.num(streak)) يوم").font(AZFont.ui(40, .heavy).monospacedDigit()).foregroundColor(AZ.lime)
                    Text("ولو بشق تمرة").font(AZFont.ui(13)).foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(18)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.06)))
                VStack(alignment: .leading, spacing: 6) {
                    Text("حاسبة الزكاة").font(AZFont.ui(15, .semibold)).foregroundColor(AZ.muted)
                    Text("\(AR.num(amount)) ج").font(AZFont.ui(24, .bold).monospacedDigit())
                    HStack(spacing: 6) {
                        Text("زكاتك").font(AZFont.ui(13)).foregroundColor(AZ.muted)
                        Text("\(AR.num(zakat)) ج").font(AZFont.ui(26, .heavy).monospacedDigit()).foregroundColor(AZ.lime)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(18)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.06)))
            }
        }
        .padding(.horizontal, 30).padding(.top, 26)
    }

    private func ramadan(_ lt: Double) -> some View {
        let days = 95 - Int(8 * M.out(M.p(lt, 0.2, 1.3)))
        let pages = 1 + Int(3 * M.out(M.p(lt, 0.4, 1.4)))
        return VStack(spacing: 16) {
            header("moon.stars.fill", AZ.violet, "رمضان", "خطتك جاهزة")
            HStack(alignment: .center, spacing: 22) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("فاضل").font(AZFont.ui(14)).foregroundColor(AZ.muted)
                    Text("\(AR.num(days)) يوم").font(AZFont.ui(52, .heavy).monospacedDigit()).foregroundColor(AZ.lime)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("وردك النهارده: \(AR.num(pages)) من \(AR.num(4)) صفحات").font(AZFont.ui(15, .semibold))
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule().fill(LinearGradient(colors: [AZ.violet, AZ.lime], startPoint: .leading, endPoint: .trailing))
                                .frame(width: g.size.width * CGFloat(pages) / 4)
                        }
                    }
                    .frame(height: 8)
                    HStack(spacing: 8) {
                        PalestineFlag().frame(width: 22, height: 14)
                        Text("لا تنسَ فلسطين في دعائك").font(AZFont.ui(14)).foregroundColor(.white.opacity(0.85))
                    }
                }
            }
        }
        .padding(.horizontal, 30).padding(.top, 26)
    }
}
