import Foundation

/// Private, on-device record of prayers confirmed with the testimony ("أُشهِد الله إني صلّيت").
/// Nothing leaves the Mac.
enum PrayerLog {
    enum Status: String { case prayed, emergency }

    private static func dayKey(_ date: Date, tz: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "log.%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func mark(_ p: Prayer, on date: Date, tz: TimeZone, _ status: Status) {
        let key = dayKey(date, tz: tz)
        var day = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        // A real "prayed" is never downgraded by a later emergency entry.
        if day[p.rawValue] == Status.prayed.rawValue && status != .prayed { return }
        day[p.rawValue] = status.rawValue
        UserDefaults.standard.set(day, forKey: key)
    }

    static func prayed(on date: Date, tz: TimeZone) -> Set<Prayer> {
        let day = UserDefaults.standard.dictionary(forKey: dayKey(date, tz: tz)) as? [String: String] ?? [:]
        return Set(day.compactMap { $0.value == Status.prayed.rawValue ? Prayer(rawValue: $0.key) : nil })
    }

    /// Consecutive days with all five prayers confirmed (counting today only once it's complete).
    static func streak(until date: Date, tz: TimeZone) -> Int {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        var n = 0
        var d = date
        if prayed(on: d, tz: tz).count < 5 { d = cal.date(byAdding: .day, value: -1, to: d) ?? d }
        while prayed(on: d, tz: tz).count >= 5 && n < 3650 {
            n += 1
            d = cal.date(byAdding: .day, value: -1, to: d) ?? d
        }
        return n
    }
}

/// Lines shown when someone asks to snooze — rotate, never repeat back-to-back.
enum SnoozeMotivation {
    static let lines: [Msg] = [
        Msg(tr("الشغل هيستنّاك… بس مين ضمن إنك هتلحق بعدين؟"), tr("ربنا بيناديك دلوقتي، والإجابة خمس دقايق.")),
        Msg(tr("لو ده أهم إيميل في يومك… الصلاة أهم منه"), tr("ردّ على اللي خلقك الأول، وبعدين ردّ على أي حد.")),
        Msg(tr("مفيش ديدلاين أقرب من الأذان"), tr("التصميم هيتسلّم، بس الوقت ده مش هيرجع.")),
        Msg(tr("خمس دقايق مع ربنا… ويرجعلك يومك أبرك"), tr("البركة في الوقت بتبدأ من السجدة.")),
        Msg(tr("التأجيل أول خطوة للتفويت"), tr("قوم دلوقتي وإنت لسه فاكر.")),
        Msg(tr("إنت مش مستعجل على الشغل… إنت مستعجل على إيه؟"), tr("اللي فاضل في عمرك أهم من اللي فاضل في الفايل.")),
    ]
    static let hadith: [Msg] = [
        Msg(tr("أحبُّ الأعمال إلى الله الصلاة على وقتها"), tr("متفق عليه")),
        Msg(tr("أول ما يُحاسَب عليه العبد يوم القيامة الصلاة"), tr("رواه الترمذي والنسائي")),
        Msg(tr("إنّ الصلاة كانت على المؤمنين كتابًا موقوتًا"), tr("النساء ١٠٣")),
        Msg(tr("فويلٌ للمصلّين ۝ الذين هم عن صلاتهم ساهون"), tr("الماعون ٤-٥")),
    ]
    static let rotator = Rotator(key: "recent.snooze", memory: 3)
    static let hadithRotator = Rotator(key: "recent.snoozeHadith", memory: 2)
}
