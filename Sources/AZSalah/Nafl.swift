import Foundation

/// Voluntary prayers: Duha (mid-morning) and Qiyam al-Layl (last third of the night).
enum Nafl: String {
    case duha, qiyam

    var title: String { self == .duha ? tr("صلاة الضحى") : tr("قيام الليل") }
    var commitText: String { self == .duha ? tr("هقوم أصلّي ركعتين دلوقتي") : tr("هقوم أصلّي دلوقتي") }
    var checkTitle: String { self == .duha ? tr("صلّيت الضحى؟") : tr("قمت الليل؟") }
    var icon: String { self == .duha ? "sun.max.fill" : "moon.stars.fill" }

    /// Duha: halfway between sunrise and Dhuhr. Qiyam: start of the last third of the night (Maghrib → Fajr).
    static func time(_ k: Nafl, today: [Prayer: Date], tomorrow: [Prayer: Date]) -> Date? {
        switch k {
        case .duha:
            guard let sr = today[.sunrise], let dh = today[.dhuhr] else { return nil }
            return sr.addingTimeInterval(dh.timeIntervalSince(sr) * 0.45)
        case .qiyam:
            guard let m = today[.maghrib], let f = tomorrow[.fajr] else { return nil }
            return m.addingTimeInterval(f.timeIntervalSince(m) * 2 / 3)
        }
    }

    static let motivation: [Nafl: [Msg]] = [
        .duha: [
            Msg(tr("يُصبح على كل سُلامى من أحدكم صدقة… ويُجزئ من ذلك ركعتان يركعهما من الضحى"), tr("رواه مسلم")),
            Msg(tr("صلاة الأوّابين حين ترمض الفصال"), tr("رواه مسلم")),
            Msg(tr("ركعتين بس… والشغل هيستنّاك خمس دقايق"), tr("اقفل الشاشة، اتوضّى، وارجع أخفّ")),
            Msg(tr("الضحى صدقة عن كل مفصل في جسمك… بركعتين"), tr("ابدأ يومك بيها")),
        ],
        .qiyam: [
            Msg(tr("ينزل ربنا كل ليلة إلى السماء الدنيا حين يبقى ثلث الليل الآخر، فيقول: من يدعوني فأستجيب له"), tr("متفق عليه")),
            Msg(tr("أفضل الصلاة بعد الفريضة صلاة الليل"), tr("رواه مسلم")),
            Msg(tr("تتجافى جنوبهم عن المضاجع يدعون ربهم خوفًا وطمعًا"), tr("السجدة ١٦")),
            Msg(tr("الدعوة اللي شايلها في قلبك… دي ساعتها"), tr("ركعتين في ثلث الليل الأخير")),
            Msg(tr("لو سهران على الشغل… خلّي آخر حاجة ركعتين وتر"), tr("واجعلوا آخر صلاتكم بالليل وترًا")),
        ],
    ]
    static let rotator = Rotator(key: "recent.nafl", memory: 3)

    // On-device log for the report
    private static func key(_ k: Nafl, _ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "nafl.\(k.rawValue).\(c.year!)-\(c.month!)-\(c.day!)"
    }
    static func mark(_ k: Nafl, on date: Date = Date()) { UserDefaults.standard.set(true, forKey: key(k, date)) }
    static func did(_ k: Nafl, on date: Date) -> Bool { UserDefaults.standard.bool(forKey: key(k, date)) }
    static func count(_ k: Nafl, lastDays n: Int) -> Int {
        (0..<n).filter { did(k, on: Calendar.current.date(byAdding: .day, value: -$0, to: Date())!) }.count
    }
}
