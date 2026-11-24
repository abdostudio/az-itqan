import Foundation

// MARK: - Prayer

enum Prayer: String, CaseIterable, Codable, Hashable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha

    static let fard: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]

    var isFard: Bool { self != .sunrise }

    func arabic(friday: Bool = false) -> String {
        switch self {
        case .fajr: return tr("الفجر")
        case .sunrise: return tr("الشروق")
        case .dhuhr: return friday ? tr("الجمعة") : tr("الظهر")
        case .asr: return tr("العصر")
        case .maghrib: return tr("المغرب")
        case .isha: return tr("العشاء")
        }
    }
}

// MARK: - Calculation settings

enum AsrSchool: String, CaseIterable, Codable, Identifiable {
    case shafi, hanafi
    var id: String { rawValue }
    var factor: Double { self == .shafi ? 1 : 2 }
    var arabic: String { self == .shafi ? tr("الجمهور (شافعي/مالكي/حنبلي)") : tr("حنفي") }
}

enum HighLatRule: String, CaseIterable, Codable, Identifiable {
    case angleBased, middleOfNight, seventhOfNight
    var id: String { rawValue }
    var arabic: String {
        switch self {
        case .angleBased: return tr("حسب الزاوية (افتراضي)")
        case .middleOfNight: return tr("منتصف الليل")
        case .seventhOfNight: return tr("سُبع الليل")
        }
    }
}

struct CalcMethod: Identifiable, Hashable {
    let id: String
    let arabic: String
    let fajrAngle: Double
    let ishaAngle: Double?      // nil → isha = maghrib + ishaMinutes
    let ishaMinutes: Double
    let maghribMinutes: Double
    let dhuhrMinutes: Double

    init(_ id: String, _ arabic: String, fajr: Double, isha: Double? = nil,
         ishaMinutes: Double = 0, maghribMinutes: Double = 0, dhuhrMinutes: Double = 0) {
        self.id = id; self.arabic = arabic; self.fajrAngle = fajr; self.ishaAngle = isha
        self.ishaMinutes = ishaMinutes; self.maghribMinutes = maghribMinutes; self.dhuhrMinutes = dhuhrMinutes
    }

    static let all: [CalcMethod] = [
        CalcMethod("egypt", tr("الهيئة المصرية العامة للمساحة"), fajr: 19.5, isha: 17.5),
        CalcMethod("ummAlQura", tr("أم القرى (السعودية)"), fajr: 18.5, ishaMinutes: 90),
        CalcMethod("mwl", tr("رابطة العالم الإسلامي"), fajr: 18, isha: 17),
        CalcMethod("dubai", tr("الإمارات (الهيئة العامة للشؤون الإسلامية)"), fajr: 18.2, isha: 18.2),
        CalcMethod("kuwait", tr("الكويت"), fajr: 18, isha: 17.5),
        CalcMethod("qatar", tr("قطر"), fajr: 18, ishaMinutes: 90),
        CalcMethod("jordan", tr("الأردن وفلسطين"), fajr: 18, isha: 18, maghribMinutes: 5),
        CalcMethod("karachi", tr("جامعة العلوم الإسلامية بكراتشي"), fajr: 18, isha: 18),
        CalcMethod("turkey", tr("رئاسة الشؤون الدينية التركية"), fajr: 18, isha: 17),
        CalcMethod("morocco", tr("المغرب"), fajr: 19, isha: 17),
        CalcMethod("algeria", tr("الجزائر"), fajr: 18, isha: 17),
        CalcMethod("tunisia", tr("تونس"), fajr: 18, isha: 18),
        CalcMethod("singapore", tr("سنغافورة وماليزيا وإندونيسيا"), fajr: 20, isha: 18),
        CalcMethod("isna", tr("أمريكا الشمالية (ISNA)"), fajr: 15, isha: 15),
        CalcMethod("france", tr("فرنسا (UOIF)"), fajr: 12, isha: 12),
        CalcMethod("russia", tr("روسيا"), fajr: 16, isha: 15),
    ]

    static func byID(_ id: String) -> CalcMethod { all.first { $0.id == id } ?? all[0] }
}

struct Location: Codable, Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
    var timeZoneID: String
    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
}

// MARK: - Calculator (PrayTimes.org algorithm)

struct PrayerCalculator {
    let location: Location
    let method: CalcMethod
    let asr: AsrSchool
    let highLat: HighLatRule
    let offsets: [Prayer: Int]

    func times(for date: Date) -> [Prayer: Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = location.timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day,
              let noon = cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) else { return [:] }

        let tzHours = Double(location.timeZone.secondsFromGMT(for: noon)) / 3600
        let lat = location.latitude, lng = location.longitude
        let jDate = julian(y, m, d) - lng / (15 * 24)

        func sunPosition(_ jd: Double) -> (decl: Double, eqt: Double) {
            let D = jd - 2451545.0
            let g = fixAngle(357.529 + 0.98560028 * D)
            let q = fixAngle(280.459 + 0.98564736 * D)
            let L = fixAngle(q + 1.915 * dsin(g) + 0.020 * dsin(2 * g))
            let e = 23.439 - 0.00000036 * D
            let RA = darctan2(dcos(e) * dsin(L), dcos(L)) / 15
            let eqt = q / 15 - fixHour(RA)
            let decl = darcsin(dsin(e) * dsin(L))
            return (decl, eqt)
        }
        func midDay(_ t: Double) -> Double { fixHour(12 - sunPosition(jDate + t).eqt) }
        func sunAngleTime(_ angle: Double, _ t: Double, ccw: Bool) -> Double {
            let decl = sunPosition(jDate + t).decl
            let noon = midDay(t)
            let v = (-dsin(angle) - dsin(decl) * dsin(lat)) / (dcos(decl) * dcos(lat))
            guard v >= -1, v <= 1 else { return .nan }
            let T = darccos(v) / 15
            return noon + (ccw ? -T : T)
        }
        func asrTime(_ factor: Double, _ t: Double) -> Double {
            let decl = sunPosition(jDate + t).decl
            let angle = -darccot(factor + dtan(abs(lat - decl)))
            return sunAngleTime(angle, t, ccw: false)
        }

        // Initial guesses (hours), one refinement pass.
        var fajr = 5.0, sunrise = 6.0, dhuhr = 12.0, asrT = 13.0, sunset = 18.0, isha = 18.0
        for _ in 0..<2 {
            let f = sunAngleTime(method.fajrAngle, fajr / 24, ccw: true)
            let sr = sunAngleTime(0.833, sunrise / 24, ccw: true)
            let dh = midDay(dhuhr / 24)
            let a = asrTime(asr.factor, asrT / 24)
            let ss = sunAngleTime(0.833, sunset / 24, ccw: false)
            let i = method.ishaAngle.map { sunAngleTime($0, isha / 24, ccw: false) } ?? ss
            fajr = f.isNaN ? fajr : f; sunrise = sr.isNaN ? sunrise : sr
            dhuhr = dh; asrT = a.isNaN ? asrT : a; sunset = ss.isNaN ? sunset : ss
            isha = i.isNaN ? isha : i
        }
        var fajrRaw = sunAngleTime(method.fajrAngle, fajr / 24, ccw: true)
        var ishaRaw = method.ishaAngle.map { sunAngleTime($0, isha / 24, ccw: false) } ?? .nan

        let shift = tzHours - lng / 15
        fajrRaw += shift; sunrise += shift; dhuhr += shift; asrT += shift; sunset += shift; ishaRaw += shift

        // High latitude adjustment
        let night = fixHour(sunrise - sunset)
        func portion(_ angle: Double) -> Double {
            switch highLat {
            case .angleBased: return night * angle / 60
            case .middleOfNight: return night / 2
            case .seventhOfNight: return night / 7
            }
        }
        let fp = portion(method.fajrAngle)
        if fajrRaw.isNaN || fixHour(sunrise - fajrRaw) > fp { fajrRaw = sunrise - fp }
        if let ia = method.ishaAngle {
            let ip = portion(ia)
            if ishaRaw.isNaN || fixHour(ishaRaw - sunset) > ip { ishaRaw = sunset + ip }
        }

        dhuhr += method.dhuhrMinutes / 60
        let maghrib = sunset + method.maghribMinutes / 60
        if method.ishaAngle == nil {
            var extra = method.ishaMinutes
            if method.id == "ummAlQura" && Hijri.isRamadan(date) { extra += 30 }
            ishaRaw = maghrib + extra / 60
        }

        let hours: [Prayer: Double] = [.fajr: fajrRaw, .sunrise: sunrise, .dhuhr: dhuhr,
                                      .asr: asrT, .maghrib: maghrib, .isha: ishaRaw]
        var out: [Prayer: Date] = [:]
        for (p, h) in hours where !h.isNaN {
            var minutes = Int((h * 60).rounded()) + (offsets[p] ?? 0)
            minutes = max(0, minutes)
            out[p] = cal.date(from: DateComponents(year: y, month: m, day: d,
                                                   hour: minutes / 60, minute: minutes % 60))
        }
        return out
    }

    // MARK: math helpers
    private func julian(_ y: Int, _ m: Int, _ d: Int) -> Double {
        var year = Double(y), month = Double(m)
        if month <= 2 { year -= 1; month += 12 }
        let A = (year / 100).rounded(.down)
        let B = 2 - A + (A / 4).rounded(.down)
        return (365.25 * (year + 4716)).rounded(.down) + (30.6001 * (month + 1)).rounded(.down) + Double(d) + B - 1524.5
    }
}

private func dtr(_ d: Double) -> Double { d * .pi / 180 }
private func rtd(_ r: Double) -> Double { r * 180 / .pi }
private func dsin(_ d: Double) -> Double { sin(dtr(d)) }
private func dcos(_ d: Double) -> Double { cos(dtr(d)) }
private func dtan(_ d: Double) -> Double { tan(dtr(d)) }
private func darcsin(_ x: Double) -> Double { rtd(asin(x)) }
private func darccos(_ x: Double) -> Double { rtd(acos(x)) }
private func darctan2(_ y: Double, _ x: Double) -> Double { rtd(atan2(y, x)) }
private func darccot(_ x: Double) -> Double { rtd(atan(1 / x)) }
private func fix(_ a: Double, _ b: Double) -> Double { let r = a - b * (a / b).rounded(.down); return r < 0 ? r + b : r }
private func fixAngle(_ a: Double) -> Double { fix(a, 360) }
private func fixHour(_ a: Double) -> Double { fix(a, 24) }

// MARK: - Hijri helpers

enum Hijri {
    static var calendar: Calendar = {
        var c = Calendar(identifier: .islamicUmmAlQura)
        c.locale = Lang.locale
        return c
    }()

    /// Hijri day/month for a date, with an optional day adjustment (local moon sighting).
    static func components(_ date: Date, adjust: Int = 0) -> (day: Int, month: Int, year: Int) {
        let d = calendar.date(byAdding: .day, value: adjust, to: date) ?? date
        let c = calendar.dateComponents([.day, .month, .year], from: d)
        return (c.day ?? 1, c.month ?? 1, c.year ?? 1448)
    }

    static func isRamadan(_ date: Date, adjust: Int = 0) -> Bool { components(date, adjust: adjust).month == 9 }

    static let monthNames = [tr("محرم"), tr("صفر"), tr("ربيع الأول"), tr("ربيع الآخر"), tr("جمادى الأولى"), tr("جمادى الآخرة"),
                             tr("رجب"), tr("شعبان"), tr("رمضان"), tr("شوال"), tr("ذو القعدة"), tr("ذو الحجة")]

    static func string(_ date: Date, adjust: Int = 0) -> String {
        let c = components(date, adjust: adjust)
        return "\(AR.num(c.day)) \(monthNames[max(0, min(11, c.month - 1))]) \(AR.num(c.year))"
    }
}
