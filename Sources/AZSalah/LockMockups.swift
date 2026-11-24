import SwiftUI
import AppKit

/// Mockups for the stricter prayer lock (limited snooze + motivation + proof). Static, not wired yet.
@MainActor enum LockMockups {
    static func render(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        func save<V: View>(_ name: String, _ view: V) {
            let size = CGSize(width: 900, height: 640)
            let r = ImageRenderer(content: view.frame(width: size.width, height: size.height)
                .environment(\.layoutDirection, .rightToLeft))
            r.scale = 2
            guard let img = r.nsImage, let tiff = img.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
            try? png.write(to: dir.appendingPathComponent("\(name).png"))
            print("wrote \(name).png")
        }
        save("4-lock-main", Backdrop { LockMain() })
        save("5-lock-snooze", Backdrop { SnoozeSheet() })
        save("6-lock-proof", Backdrop { ProofSheet() })
    }
}

private struct Backdrop<C: View>: View {
    @ViewBuilder let content: () -> C
    var body: some View {
        ZStack {
            AZ.deepGradient
            RadialGradient(colors: [AZ.royal.opacity(0.5), .clear], center: .center, startRadius: 10, endRadius: 480)
            content()
        }
        .foregroundColor(.white)
    }
}

private struct PrimaryButton: View {
    let text: String
    var icon: String? = nil
    var dim = false
    var body: some View {
        HStack(spacing: 7) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }
        .font(.system(size: 15, weight: .bold))
        .foregroundColor(AZ.navy)
        .padding(.horizontal, 24).padding(.vertical, 12)
        .background(Capsule().fill(dim ? AnyShapeStyle(Color.white.opacity(0.3)) : AnyShapeStyle(AZ.accentGradient)))
    }
}

private struct GhostButton: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(AZ.muted)
            .padding(.horizontal, 18).padding(.vertical, 10)
            .background(Capsule().fill(Color.white.opacity(0.06)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8))
    }
}

// 1. Main lock: snooze is no longer a big button, just a quiet link
private struct LockMain: View {
    var body: some View {
        VStack(spacing: 14) {
            Text("حان الآن موعد صلاة").font(.system(size: 16, weight: .medium)).foregroundColor(AZ.muted)
            Text("العصر").font(AZFont.thuluth(80))
                .foregroundStyle(LinearGradient(colors: [.white, AZ.lime], startPoint: .top, endPoint: .bottom))
            Text("الصلاة الوسطى").font(.system(size: 17, weight: .semibold)).foregroundColor(AZ.lime)
            Text("حافظوا على الصلوات والصلاة الوسطى").font(AZFont.naskh(28))
            Text("البقرة ٢٣٨").font(.system(size: 12)).foregroundColor(AZ.muted)
            Spacer().frame(height: 18)
            PrimaryButton(text: "صلّيت (متاح بعد ٠٢:١٠)", icon: "checkmark.seal.fill", dim: true)
            HStack(spacing: 18) {
                Text("محتاج تأجّل؟").underline()
                Text("·")
                Text("طوارئ حقيقية").underline()
            }
            .font(.system(size: 12, weight: .medium)).foregroundColor(AZ.muted.opacity(0.8))
            Text("التأجيل مرة واحدة بس، ولحد ٥ دقايق").font(.system(size: 11)).foregroundColor(AZ.muted.opacity(0.6))
        }
    }
}

// 2. Snooze confirmation: motivation first, and the snooze button waits a few seconds
private struct SnoozeSheet: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hourglass").font(.system(size: 26)).foregroundColor(AZ.lime)
            Text("مفيش حاجة أهم من الصلاة دلوقتي").font(.system(size: 22, weight: .bold))
            Text("الشغل هيستنّاك… بس مين ضمن إنك هتلحق بعدين؟\nربنا بيناديك دلوقتي، والإجابة خمس دقايق.")
                .font(.system(size: 15)).foregroundColor(AZ.muted).multilineTextAlignment(.center).lineSpacing(5)
            Text("«أحبُّ الأعمال إلى الله الصلاة على وقتها» — متفق عليه")
                .font(AZFont.naskh(20)).foregroundColor(.white.opacity(0.9))
                .padding(.top, 4)
            HStack(spacing: 12) {
                PrimaryButton(text: "هقوم أصلّي", icon: "figure.stand")
                GhostButton(text: "أأجّل ٥ دقايق (استنى ٨)")
            }
            .padding(.top, 8)
            Text("ده التأجيل الوحيد في الصلاة دي").font(.system(size: 11)).foregroundColor(AZ.muted.opacity(0.7))
        }
        .padding(34)
        .frame(width: 600)
        .background(RoundedRectangle(cornerRadius: 26).fill(Color.black.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8))
    }
}

// 3. Proof: a sincere testimony held for 3 seconds + a private streak
private struct ProofSheet: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("قبل ما جهازك يرجع").font(.system(size: 14, weight: .medium)).foregroundColor(AZ.muted)
            Text("أُشهِد الله إني صلّيت العصر").font(AZFont.naskh(36))
            Text("الصلاة بينك وبين ربنا… والأداة بتساعدك بس تفتكر").font(.system(size: 13)).foregroundColor(AZ.muted)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(AZ.accentGradient).frame(width: 150)
                HStack(spacing: 8) {
                    Image(systemName: "hand.raised.fill")
                    Text("اضغط مطوّل ٣ ثواني")
                }
                .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                .frame(maxWidth: .infinity)
            }
            .frame(width: 300, height: 48)
            .environment(\.layoutDirection, .leftToRight)
            HStack(spacing: 10) {
                ForEach(["الفجر", "الظهر", "العصر", "المغرب", "العشاء"], id: \.self) { p in
                    VStack(spacing: 4) {
                        Circle().fill(["الفجر", "الظهر"].contains(p) ? AnyShapeStyle(AZ.lime) : AnyShapeStyle(Color.white.opacity(0.12)))
                            .frame(width: 12, height: 12)
                        Text(p).font(.system(size: 10.5)).foregroundColor(AZ.muted)
                    }
                }
            }
            .padding(.top, 6)
            Text("٧ أيام متتالية ما فاتتكش صلاة — الحمد لله").font(.system(size: 12.5, weight: .semibold)).foregroundColor(AZ.lime)
            Text("السجل ده على جهازك بس، ومحدش بيشوفه غيرك").font(.system(size: 10.5)).foregroundColor(AZ.muted.opacity(0.7))
        }
        .padding(34)
        .frame(width: 600)
        .background(RoundedRectangle(cornerRadius: 26).fill(Color.black.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8))
    }
}
