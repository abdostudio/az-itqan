import SwiftUI
import AppKit

/// Design mockups for the "AZ Itqan" direction (community tabs). Static views, not wired to data yet.
/// Rendered with `AZSalah --mockups <dir>`.
@MainActor enum Mockups {
    static func render(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let settings = AppSettings.shared
        let engine = PrayerEngine(settings: settings)
        let notchW: CGFloat = 185, notchH: CGFloat = 32

        func save<V: View>(_ name: String, _ view: V, _ size: CGSize) {
            let r = ImageRenderer(content: view.frame(width: size.width, height: size.height)
                .environment(\.layoutDirection, .rightToLeft))
            r.scale = 2
            guard let img = r.nsImage, let tiff = img.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
            try? png.write(to: dir.appendingPathComponent("\(name).png"))
            print("wrote \(name).png")
        }

        func scene<C: View>(height: CGFloat, @ViewBuilder _ island: () -> C) -> some View {
            ZStack(alignment: .top) {
                LinearGradient(colors: [Color(hex: 0x8DA2C8), Color(hex: 0xC9B8D9)], startPoint: .top, endPoint: .bottom)
                Rectangle().fill(Color.white.opacity(0.35)).frame(height: notchH)
                island()
                UnevenRoundedRectangle(bottomLeadingRadius: 9, bottomTrailingRadius: 9)
                    .fill(Color(hex: 0x1A1A1A))
                    .overlay(Circle().fill(Color(hex: 0x2B3550)).frame(width: 6, height: 6))
                    .frame(width: notchW, height: notchH)
            }
            .frame(height: height)
        }

        // 0. Idle strip showing a community item
        save("0-idle-community", scene(height: 110) {
            MockIsland(width: 420, height: notchH + 24, radius: 11, ambient: true) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: notchH)
                    HStack(spacing: 7) {
                        AZSwoosh().fill(AZ.lime).frame(width: 13, height: 8)
                        Text("مشروع جديد من المجتمع خد فيتشر على Behance").font(.system(size: 11.5, weight: .semibold))
                        Image(systemName: "arrow.up.left").font(.system(size: 9, weight: .bold)).foregroundColor(AZ.lime)
                    }
                    .frame(maxHeight: .infinity).padding(.bottom, 3)
                }
            }
        }, CGSize(width: 640, height: 110))

        let w: CGFloat = 540, h: CGFloat = notchH + 262
        // 1. Daily tab
        save("1-tab-daily", scene(height: h + 30) {
            MockIsland(width: w, height: h, radius: 26) {
                MockPanel(tab: 0, notchW: notchW, notchH: notchH) { DailyTab(engine: engine) }
            }
        }, CGSize(width: 640, height: h + 30))
        // 2. Community tab
        let hc = h + 46
        save("2-tab-community", scene(height: hc + 30) {
            MockIsland(width: w, height: hc, radius: 26) {
                MockPanel(tab: 1, notchW: notchW, notchH: notchH) { CommunityTab() }
            }
        }, CGSize(width: 640, height: hc + 30))
        // 3. Tools tab
        save("3-tab-tools", scene(height: h + 30) {
            MockIsland(width: w, height: h, radius: 26) {
                MockPanel(tab: 2, notchW: notchW, notchH: notchH) { ToolsTab() }
            }
        }, CGSize(width: 640, height: h + 30))
    }
}

// MARK: - Shell

private struct MockIsland<C: View>: View {
    let width: CGFloat, height: CGFloat, radius: CGFloat
    var ambient = false
    @ViewBuilder let content: () -> C
    var body: some View {
        ZStack(alignment: .top) {
            if ambient {
                LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.62),
                                       .init(color: AZ.navy, location: 0.85), .init(color: AZ.indigo.opacity(0.85), location: 1)],
                               startPoint: .top, endPoint: .bottom)
            } else {
                LinearGradient(colors: [.black, AZ.navy, AZ.indigo.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            }
            content()
        }
        .frame(width: width, height: height, alignment: .top)
        .clipShape(NotchShape(radius: radius))
        .foregroundColor(.white)
    }
}

private struct MockPanel<C: View>: View {
    let tab: Int
    let notchW: CGFloat, notchH: CGFloat
    @ViewBuilder let content: () -> C
    let tabs = ["يومي", "المجتمع", "أدوات"]

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    AZSwoosh().fill(AZ.lime).frame(width: 15, height: 9)
                    Text("AZ Itqan").font(.system(size: 12, weight: .bold)).environment(\.layoutDirection, .leftToRight)
                }
                Spacer(minLength: notchW + 10)
                Text("العصر بعد ٢٣ د").font(.system(size: 10.5, weight: .medium)).foregroundColor(AZ.muted)
            }
            .frame(height: notchH)
            .padding(.horizontal, 26)

            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Text(tabs[i])
                        .font(.system(size: 11.5, weight: i == tab ? .bold : .medium))
                        .foregroundColor(i == tab ? AZ.navy : AZ.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                        .background(Capsule().fill(i == tab ? AnyShapeStyle(AZ.accentGradient) : AnyShapeStyle(Color.clear)))
                }
            }
            .padding(3)
            .background(Capsule().fill(Color.white.opacity(0.06)))
            .frame(width: 300)

            content().padding(.horizontal, 18)
            Spacer(minLength: 0)
        }
    }
}

private struct Card<C: View>: View {
    var tint: Color? = nil
    @ViewBuilder let content: () -> C
    var body: some View {
        content()
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 14).fill(
                tint.map { AnyShapeStyle(LinearGradient(colors: [$0.opacity(0.22), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)) }
                ?? AnyShapeStyle(AZ.cardGradient)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AZ.line, lineWidth: 0.5))
    }
}

private struct LinkChip: View {
    let text: String
    var icon = "arrow.up.left"
    var strong = false
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
            Image(systemName: icon).font(.system(size: 8.5, weight: .bold))
        }
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundColor(strong ? AZ.navy : AZ.lime)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill(strong ? AnyShapeStyle(AZ.accentGradient) : AnyShapeStyle(AZ.lime.opacity(0.12))))
    }
}

// MARK: - Tabs

private struct DailyTab: View {
    @ObservedObject var engine: PrayerEngine
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Prayer.fard, id: \.self) { p in
                    let on = p == .asr
                    VStack(spacing: 2) {
                        Text(p.arabic()).font(.system(size: 10, weight: .medium)).foregroundColor(on ? AZ.lime : AZ.muted)
                        Text(engine.today[p].map { AR.time($0, tz: engine.tz) } ?? "—").font(.system(size: 14, weight: .semibold).monospacedDigit())
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 10).fill(on ? AnyShapeStyle(AZ.royal.opacity(0.4)) : AnyShapeStyle(AZ.cardGradient)))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(on ? AZ.lime.opacity(0.8) : AZ.line, lineWidth: on ? 1 : 0.5))
                }
            }
            HStack(spacing: 8) {
                Card {
                    HStack(spacing: 9) {
                        ZStack {
                            Circle().stroke(Color.white.opacity(0.1), lineWidth: 3)
                            Circle().trim(from: 0, to: 0.45).stroke(AZ.accentGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                            Text("١٥").font(.system(size: 12, weight: .bold))
                        }.frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("سبحان الله").font(.system(size: 12.5, weight: .semibold))
                            Text("اضغط للتسبيح").font(.system(size: 9.5)).foregroundColor(AZ.muted)
                        }
                    }
                }
                Card(tint: Color(hex: 0x149954)) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) { PalestineFlag().frame(width: 16, height: 11); Text("فلسطين").font(.system(size: 11, weight: .semibold)) }
                        Text("اللهم انصر أهلنا في فلسطين").font(.system(size: 11)).lineLimit(1)
                    }
                }
            }
            Card {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.1), lineWidth: 3)
                        Circle().trim(from: 0, to: 0.62).stroke(LinearGradient(colors: [AZ.violet, AZ.lime], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                        Image(systemName: "scope").font(.system(size: 12)).foregroundColor(AZ.lime)
                    }.frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ركّز لحد العصر").font(.system(size: 12.5, weight: .semibold))
                        Text("٢٣ دقيقة شغل مركّز… والأذان هو البريك").font(.system(size: 9.5)).foregroundColor(AZ.muted)
                    }
                    Spacer()
                    LinkChip(text: "ابدأ", icon: "play.fill", strong: true)
                }
            }
        }
    }
}

private struct CommunityTab: View {
    var body: some View {
        VStack(spacing: 8) {
            // Weekly brief
            Card(tint: AZ.lime) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("تاسك الأسبوع").font(.system(size: 10, weight: .bold)).foregroundColor(AZ.lime)
                        Text("بوستر لمعرض خط عربي — ستايل سويسري").font(.system(size: 13, weight: .semibold))
                        Text("باقي ٣ أيام · ٤٨ مشارك").font(.system(size: 9.5)).foregroundColor(AZ.muted)
                    }
                    Spacer()
                    VStack(spacing: 5) {
                        LinkChip(text: "البريف", icon: "doc.text")
                        LinkChip(text: "ابعت شغلك", icon: "paperplane.fill", strong: true)
                    }
                }
            }
            HStack(spacing: 8) {
                // Featured project
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [Color(hex: 0xF2C14E), Color(hex: 0xE76F51), Color(hex: 0x264653)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(height: 54)
                            .overlay(Text("Brand").font(.system(size: 18, weight: .black)).foregroundColor(.white.opacity(0.9)).environment(\.layoutDirection, .leftToRight))
                        Text("هوية مطعم «سُفرة»").font(.system(size: 11.5, weight: .semibold))
                        HStack {
                            Text("سارة محمد · فيتشر").font(.system(size: 9.5)).foregroundColor(AZ.muted)
                            Spacer()
                            LinkChip(text: "Behance")
                        }
                    }
                }
                // Resource of the day
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Aa").font(.system(size: 26, weight: .bold, design: .serif)).environment(\.layoutDirection, .leftToRight)
                            Spacer()
                            Text("أبجد").font(AZFont.naskh(26))
                        }
                        .frame(height: 54)
                        Text("خط اليوم: Rubik Arabic").font(.system(size: 11.5, weight: .semibold))
                        HStack {
                            Text("مجاني · ٩ أوزان").font(.system(size: 9.5)).foregroundColor(AZ.muted)
                            Spacer()
                            LinkChip(text: "تحميل", icon: "arrow.down")
                        }
                    }
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundColor(AZ.lime)
                Text("إصدار جديد: AZ Arrange 12.6 — تقسيم بالأشكال").lineLimit(1)
                Spacer()
                Text("شوف").foregroundColor(AZ.lime)
            }
            .font(.system(size: 10.5, weight: .medium))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(Color.white.opacity(0.06)))
        }
    }
}

private struct ToolsTab: View {
    let palette: [(UInt32, String)] = [(0x1B2A49, "#1B2A49"), (0xE9C46A, "#E9C46A"), (0xF4A261, "#F4A261"), (0xE76F51, "#E76F51"), (0xF1FAEE, "#F1FAEE")]
    var body: some View {
        VStack(spacing: 8) {
            // Drop zone with a finished analysis
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [Color(hex: 0x1B2A49), Color(hex: 0xE76F51), Color(hex: 0xE9C46A)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 46, height: 46)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("تحليل الدايركشن").font(.system(size: 10, weight: .bold)).foregroundColor(AZ.lime)
                            Text("moodboard-campaign.jpg").font(.system(size: 12, weight: .semibold)).environment(\.layoutDirection, .leftToRight)
                            HStack(spacing: 4) {
                                ForEach(["دافي", "ريترو", "إديتوريال"], id: \.self) { t in
                                    Text(t).font(.system(size: 9.5, weight: .medium))
                                        .padding(.horizontal, 7).padding(.vertical, 2)
                                        .background(Capsule().fill(Color.white.opacity(0.08)))
                                }
                            }
                        }
                        Spacer()
                        LinkChip(text: "نسخ الباليت", icon: "doc.on.doc")
                    }
                    HStack(spacing: 5) {
                        ForEach(palette, id: \.1) { c in
                            VStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 6).fill(Color(hex: c.0)).frame(height: 26)
                                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
                                Text(c.1).font(.system(size: 8.5, weight: .medium).monospaced()).foregroundColor(AZ.muted)
                            }
                        }
                    }
                    .environment(\.layoutDirection, .leftToRight)
                }
            }
            // Empty drop target
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down").foregroundColor(AZ.lime)
                Text("اسحب صورة أو مودبورد على النوتش عشان تتحلل").font(.system(size: 11, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundColor(AZ.lime.opacity(0.45)))
            HStack(spacing: 8) {
                Card {
                    HStack { Image(systemName: "eyedropper").foregroundColor(AZ.lime); Text("قطّارة ألوان").font(.system(size: 11, weight: .medium)) }
                }
                Card {
                    HStack { Image(systemName: "textformat").foregroundColor(AZ.lime); Text("تعرّف على خط").font(.system(size: 11, weight: .medium)) }
                }
                Card {
                    HStack { Image(systemName: "square.grid.2x2").foregroundColor(AZ.lime); Text("ريسورسز").font(.system(size: 11, weight: .medium)) }
                }
            }
        }
    }
}
