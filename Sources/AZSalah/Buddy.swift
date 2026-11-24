import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// Prayer buddy: invite a friend to pray together over WhatsApp.
/// Before the adhan it opens WhatsApp on the Mac; on the prayer screen it shows a QR code for the phone.
enum Buddy {
    static var settings: AppSettings { AppSettings.shared }
    static var enabled: Bool { settings.buddyEnabled }
    static var name: String { settings.buddyName.trimmingCharacters(in: .whitespaces) }
    /// Digits only, international format without "+" (e.g. 2010…).
    static var phone: String {
        var d = settings.buddyPhone.filter(\.isNumber)
        if d.hasPrefix("00") { d.removeFirst(2) }
        if d.hasPrefix("0") && d.count == 11 { d = "2" + d }      // Egyptian local number → +20
        return d
    }

    static let messages = [
        "يلا نصلّي %@ سوا 🤍",
        "%@ أذّن… قوم نصلّي وبعدين نكمّل",
        "فكّرني وأفكّرك… يلا نصلّي %@",
        "الصلاة قبل الشغل… يلا %@ سوا",
        "صلاة الجماعة بسبع وعشرين درجة… نصلّي %@ سوا؟",
        "سيب اللي في إيدك خمس دقايق… يلا %@",
    ]
    static let rotator = Rotator(key: "recent.buddy", memory: 3)

    /// Short motivation lines (kept short so the QR code stays easy to scan).
    static let motivation = [
        "الصلاة نور", "أرحنا بها يا بلال", "وجُعلت قرة عيني في الصلاة", "ألا بذكر الله تطمئن القلوب",
        "ركعتين يغيّروا يومك", "الصلاة راحة مش حمل", "أول ما يُحاسب عليه العبد الصلاة", "إن الصلاة تنهى عن الفحشاء والمنكر",
        "حافظوا على الصلوات", "الشغل هيستنّى… الصلاة لأ", "واستعينوا بالصبر والصلاة", "البركة في الوقت بتيجي من هنا",
    ]
    static let motivationRotator = Rotator(key: "recent.buddyMotivation", memory: 5)

    /// Invitation + a rotating motivation line + the app name (no links).
    static func message(_ prayer: Prayer, friday: Bool, emoji: Bool = true) -> String {
        var invite = trf(rotator.pick(messages.map { Msg($0) }).text, prayer.arabic(friday: friday))
        if !emoji { invite = invite.replacingOccurrences(of: " 🤍", with: "") }
        let line = tr(motivationRotator.pick(motivation.map { Msg($0) }).text)
        return "\(invite)\n«\(line)»\n— AZ Itqan"
    }

    /// https link — works on the phone (QR) and as a fallback on the Mac.
    static func webURL(_ text: String) -> URL? {
        var c = URLComponents(string: "https://wa.me/" + phone)
        c?.queryItems = [URLQueryItem(name: "text", value: text)]
        return c?.url
    }

    /// Opens WhatsApp on the Mac (the app if installed, otherwise WhatsApp Web).
    static func send(_ prayer: Prayer, friday: Bool) {
        let text = message(prayer, friday: friday)
        var app = URLComponents(string: "whatsapp://send")
        app?.queryItems = [URLQueryItem(name: "text", value: text)] + (phone.isEmpty ? [] : [URLQueryItem(name: "phone", value: phone)])
        if let u = app?.url, NSWorkspace.shared.urlForApplication(toOpen: u) != nil {
            NSWorkspace.shared.open(u)
        } else if let u = webURL(text) {
            NSWorkspace.shared.open(u)
        }
        LockLog.write("buddy invite sent")
    }

    static var buttonTitle: String { name.isEmpty ? tr("ابعت لصاحبك") : trf("ابعت لـ %@", name) }

    /// Short message for the QR code — fewer characters = fewer, bigger squares = easier to scan.
    static func qrText(_ prayer: Prayer, friday: Bool) -> String { message(prayer, friday: friday, emoji: false) }

    /// Crisp QR (whole-pixel modules, low density) as a bitmap.
    static func qr(_ string: String, size: CGFloat) -> NSImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(string.utf8)
        f.correctionLevel = "L"
        guard let img = f.outputImage else { return nil }
        let px = Int(size * 2)
        let k = max(1, (px / Int(img.extent.width)))
        let scaled = img.transformed(by: CGAffineTransform(scaleX: CGFloat(k), y: CGFloat(k)))
        let ctx = CIContext(options: [.useSoftwareRenderer: false])
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: size, height: size))
    }
}

/// Small card on the prayer screen: scan with the phone to invite your buddy.
struct BuddyQRCard: View {
    let prayer: Prayer
    let friday: Bool
    var body: some View {
        let text = Buddy.qrText(prayer, friday: friday)
        HStack(spacing: 14) {
            if let u = Buddy.webURL(text), let img = Buddy.qr(u.absoluteString, size: 120) {
                // White margin (quiet zone) so phone cameras lock on quickly.
                Image(nsImage: img).interpolation(.none).resizable().frame(width: 120, height: 120)
                    .padding(9).background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(Buddy.name.isEmpty ? tr("صلّي مع صاحبك") : trf("صلّي مع %@", Buddy.name))
                    .font(AZFont.ui(12, .semibold))
                Text(tr("صوّر الكود بموبايلك… وابعتله على واتساب")).font(AZFont.ui(10.5)).foregroundColor(AZ.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 130, alignment: .leading)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.6))
    }
}

/// Settings rows.
struct BuddySettings: View {
    @ObservedObject var settings: AppSettings
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(tr("صاحب الصلاة: ادعي صاحبك يصلّي معاك (زرار واتساب قبل الأذان، وكود في شاشة الصلاة)"),
                   isOn: $settings.buddyEnabled).font(AZFont.ui(12.5))
            if settings.buddyEnabled {
                HStack(spacing: 8) {
                    field(tr("اسمه (اختياري)"), $settings.buddyName, width: 150)
                    field(tr("رقم الواتساب (اختياري)"), $settings.buddyPhone, width: 170)
                }
                Text(tr("لو مكتبتش رقم، واتساب هيفتح وتختار إنت تبعت لمين. الاسم والرقم على جهازك بس."))
                    .font(AZFont.ui(11)).foregroundColor(AZ.muted)
            }
        }
    }
    private func field(_ placeholder: String, _ value: Binding<String>, width: CGFloat) -> some View {
        Group {
            if RenderMode.offscreen { Text(value.wrappedValue.isEmpty ? placeholder : value.wrappedValue) }
            else { TextField(placeholder, text: value).textFieldStyle(.plain) }
        }
        .font(AZFont.ui(12))
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.06)))
        .frame(width: width)
    }
}
