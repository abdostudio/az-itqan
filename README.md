# AZ Itqan · إتقان

**إتقان في الشغل… وإتقان في الصلاة** — a macOS notch app by **AZ Creative** (Abdelrahman Ahmed).

أداة للماك بتقعد على النوتش: مواعيد الصلاة، وذِكر بيتنفّس، وشاشة صلاة بتقفل الجهاز وقت الأذان لحد ما تقوم تصلّي.

## المميزات · Features
- مواعيد الصلاة بـ ١٦ طريقة حساب وحوالي ٣٠٠ مدينة (كل محافظات مصر) أو موقعك بالـ GPS · Prayer times (16 methods, ~300 cities, GPS)
- النوتش في حجم الكاميرا، وخط «بنزين» بيفضى لحد الأذان ويتملي لما تصلّي · Camera-sized notch with a prayer "fuel" line
- شاشة الصلاة على كل الشاشات، مش بتفتح لوحدها، وتأجيل محدود · Full-screen prayer lock that never unlocks by itself
- صاحب الصلاة: ادعي صاحبك على واتساب (زرار + QR) · Prayer buddy over WhatsApp
- أذكار الصباح والمساء جوه النوتش، والورد اليومي، والضحى وقيام الليل · Morning/evening adhkar, daily Quran portion, Duha & Qiyam
- الصدقة وحاسبة الزكاة، وصلة الرحم، وخطة رمضان، وتقرير أسبوعي وشهري · Charity, zakat, family ties, Ramadan plan, reports
- فلسطين في القلب · Palestine in every day
- عربي و English، وخفيفة جدًا على الجهاز · Arabic & English, very light on resources

## التشغيل · Build
Swift Package (macOS 13+), works with Command Line Tools — no Xcode needed.
```bash
./build.sh --install     # build and install to /Applications
```
- `AZSalah --print-times cairo 2026-11-23` — print the times for a city/date
- `AZSalah --snapshot <folder>` — render every screen to PNG

## النسخ · Releases
```bash
./release.sh 1.4.0 "what's new"   # → dist/AZ-Itqan-1.4.0.zip + dist/version.json
```
ارفع الملفين على `github.com/abdostudio/az-itqan/releases/new` بـ Tag `v1.4.0`. الأداة بتشيّك على `releases/latest/download/version.json`.

### أول تسطيب · First install
النسخة مش موقّعة بحساب Apple Developer، فأول مرة: **System Settings ← Privacy & Security ← Open Anyway**.
The app isn't notarized; on first launch use **System Settings → Privacy & Security → Open Anyway**.

## الملفات · Layout
| File | What |
|---|---|
| `PrayerCalculator.swift` | PrayTimes algorithm, methods, Hijri |
| `Cities.swift` | Cities (Arabic + English names) |
| `PrayerEngine.swift` | Timers and events (adhan, alerts, reminders) |
| `Notch.swift` | The island: idle, breathing dhikr, alerts, expanded tabs |
| `Lock.swift` | Prayer screen |
| `Buddy.swift`, `Rahim.swift`, `Giving.swift`, `Nafl.swift`, `QuranWird.swift`, `RamadanPlan.swift`, `MorningEvening.swift` | Features |
| `Content.swift` | Adhkar, du'as, motivation |
| `L10n.swift`, `L10nEN.swift` | Language switch and English text |

## Credits
Quran text (share cards): [Tanzil Project](https://tanzil.net) — Uthmani text v1.1, CC BY 3.0, used verbatim. Tafsir: التفسير الميسر, King Fahad Quran Complex (via Tanzil).

Adhan recordings from Wikimedia Commons: Adhan 1 — public domain; Adhan 2 — Atcovi, CC BY-SA 4.0; Adhan 3 — ejaz215, CC BY 3.0 (trimmed and faded).

© AZ Creative — Abdelrahman Ahmed. All rights reserved.
