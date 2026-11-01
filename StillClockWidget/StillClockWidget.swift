import WidgetKit
import SwiftUI

// MARK: - Models for Widget
struct SimplePrayerInfo {
    let name: String
    let arabic: String
    let date: Date
    let timeStr: String
}

enum WidgetAthanState {
    case elapsed(prayer: String, mins: Int)
    case imminent(prayer: String, mins: Int)
    case upcoming(prayer: String, countdown: String)
}

struct ClockWidgetEntry: TimelineEntry {
    let date: Date
    let athanState: WidgetAthanState
    let nextPrayer: String
    let prayers: [SimplePrayerInfo]
    let todayWeatherTemp: String
    let weatherPhrase: String
    let weatherSymbol: String
    let day2Label: String
    let day2Temp: String
    let day3Label: String
    let day3Temp: String
}

// MARK: - Offline Calculation / Timing Helper for Jordan
struct JordanPrayerCalc {
    static let prayerNames = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
    static let prayerArabic = ["الفجر", "الظهر", "العصر", "المغرب", "العشاء"]
    
    // Default fallback times for Jordan (Amman) if offline
    static func getTimings(for baseDate: Date) -> [SimplePrayerInfo] {
        let cal = Calendar(identifier: .gregorian)
        var comp = cal.dateComponents([.year, .month, .day], from: baseDate)
        
        let ammanTZ = TimeZone(identifier: "Asia/Amman") ?? .current
        
        // Check UserDefaults cached timings from main app
        let df = DateFormatter()
        df.timeZone = ammanTZ
        df.dateFormat = "dd-MM-yyyy"
        let dateStr = df.string(from: baseDate)
        let cacheKey = "stillclock_prayers_Amman_\(dateStr)"
        let cached = UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: String]
        
        var result: [SimplePrayerInfo] = []
        let hourFormat = DateFormatter()
        hourFormat.timeZone = ammanTZ
        hourFormat.dateFormat = "h:mm a"
        
        // Standard hours/mins offsets for Amman as reliable base
        let defaults: [String: (Int, Int)] = [
            "Fajr": (5, 42),
            "Dhuhr": (12, 21),
            "Asr": (15, 23),
            "Maghrib": (17, 52),
            "Isha": (19, 11)
        ]
        
        for (i, name) in prayerNames.enumerated() {
            var prayerDate: Date? = nil
            if let rawTime = cached?[name] {
                let iso = ISO8601DateFormatter()
                prayerDate = iso.date(from: rawTime)
            }
            if prayerDate == nil {
                let (h, m) = defaults[name] ?? (12, 0)
                comp.hour = h
                comp.minute = m
                comp.second = 0
                comp.timeZone = ammanTZ
                prayerDate = cal.date(from: comp)
            }
            
            let finalDate = prayerDate ?? baseDate
            result.append(SimplePrayerInfo(
                name: name,
                arabic: prayerArabic[i],
                date: finalDate,
                timeStr: hourFormat.string(from: finalDate)
            ))
        }
        return result
    }
}

// MARK: - Timeline Provider
struct StillClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClockWidgetEntry {
        createEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (ClockWidgetEntry) -> ()) {
        completion(createEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockWidgetEntry>) -> ()) {
        let currentDate = Date()
        var entries: [ClockWidgetEntry] = []
        
        // Generate updates for the next 2 hours at 1-minute intervals for accurate athan countdowns
        for minuteOffset in 0..<60 {
            if let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate) {
                entries.append(createEntry(date: entryDate))
            }
        }

        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate) ?? currentDate
        let timeline = Timeline(entries: entries, policy: .after(nextRefresh))
        completion(timeline)
    }
    
    private func createEntry(date: Date) -> ClockWidgetEntry {
        let prayers = JordanPrayerCalc.getTimings(for: date)
        
        // 1. Check if within 30 minutes after any prayer
        var alertState: WidgetAthanState? = nil
        for p in prayers {
            let diff = date.timeIntervalSince(p.date)
            if diff >= 0 && diff <= (30 * 60) {
                let mins = Int(diff) / 60
                alertState = .elapsed(prayer: p.name, mins: mins)
                break
            }
        }
        
        // 2. Find next upcoming prayer
        let upcoming = prayers.filter { $0.date > date }.sorted { $0.date < $1.date }
        let next = upcoming.first
        
        let nextName = next?.name ?? "Fajr"
        if let next = next {
            let rem = next.date.timeIntervalSince(date)
            if alertState == nil && rem <= (10 * 60) {
                let mins = Int(rem) / 60
                alertState = .imminent(prayer: next.name, mins: mins)
            } else if alertState == nil {
                let hrs = Int(rem) / 3600
                let mins = (Int(rem) % 3600) / 60
                let countdown = hrs > 0 ? "\(hrs)h \(mins)m" : "\(mins)m"
                alertState = .upcoming(prayer: next.name, countdown: countdown)
            }
        }
        
        let finalState = alertState ?? .upcoming(prayer: nextName, countdown: "Pending")
        
        return ClockWidgetEntry(
            date: date,
            athanState: finalState,
            nextPrayer: nextName,
            prayers: prayers,
            todayWeatherTemp: "22° / 12°C",
            weatherPhrase: "Clear sky",
            weatherSymbol: "sun.max.fill",
            day2Label: "Tomorrow",
            day2Temp: "23° / 13°C",
            day3Label: "Day 3",
            day3Temp: "21° / 11°C"
        )
    }
}

// MARK: - Widget Views
struct StillClockWidgetEntryView: View {
    var entry: StillClockProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07)
                .ignoresSafeArea()
            
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            default:
                largeView
            }
        }
    }
    
    // MARK: - Small Widget (Focus on Athan Status + Clock)
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("still/clock")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.cyan)
                Spacer()
                Circle()
                    .fill(Color.green)
                    .frame(width: 5, height: 5)
            }
            
            Text(timeString(from: entry.date))
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            switch entry.athanState {
            case .elapsed(let prayer, let mins):
                VStack(alignment: .leading, spacing: 1) {
                    Text("+ \(mins)m POST-ATHAN")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.5))
                    Text(prayer.uppercased())
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            case .imminent(let prayer, let mins):
                VStack(alignment: .leading, spacing: 1) {
                    Text("- \(mins)m IMMINENT")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color.orange)
                    Text(prayer.uppercased())
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            case .upcoming(let prayer, let cd):
                VStack(alignment: .leading, spacing: 1) {
                    Text("NEXT / \(prayer.uppercased())")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.gray)
                    Text("In \(cd)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(red: 0.4, green: 0.75, blue: 0.95))
                }
            }
        }
        .padding(12)
    }

    // MARK: - Medium Widget (Time, Dynamic Athan Banner, Weather & Next Prayer)
    private var mediumView: some View {
        HStack(spacing: 14) {
            // Left: Clock & Date
            VStack(alignment: .leading, spacing: 4) {
                Text("const now =")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
                
                Text(timeString(from: entry.date))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text("{ today }")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(Color.gray.opacity(0.8))
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: entry.weatherSymbol)
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                    Text(entry.todayWeatherTemp)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: 140, alignment: .leading)
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Right: Dynamic Athan Widget + 3-day overview
            VStack(alignment: .leading, spacing: 6) {
                switch entry.athanState {
                case .elapsed(let prayer, let mins):
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Color.green)
                            .font(.system(size: 11))
                        Text("ATHAN RECENT (+30m)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.green)
                    }
                    Text("+\(mins)m since \(prayer)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                case .imminent(let prayer, let mins):
                    HStack {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(Color.orange)
                            .font(.system(size: 11))
                        Text("ATHAN IMMINENT (-10m)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.orange)
                    }
                    Text("-\(mins)m until \(prayer)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                case .upcoming(let prayer, let cd):
                    Text("NEXT PRAYER")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.gray)
                    Text("\(prayer) in \(cd)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.4, green: 0.8, blue: 0.95))
                }
                
                Spacer()
                
                // Mini 3-Day Forecast Strip
                HStack(spacing: 8) {
                    miniDay(label: "Tmrw", temp: entry.day2Temp)
                    miniDay(label: "Day 3", temp: entry.day3Temp)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
    }

    // MARK: - Large Widget (Full StillClock Dashboard on Home Screen)
    private var largeView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("still / clock")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Text("AMMAN / JORDAN")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.green)
            }
            
            // Hero Time
            HStack(alignment: .firstTextBaseline) {
                Text(timeString(from: entry.date))
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Text(entry.weatherPhrase)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.gray)
            }
            
            // Athan Banner
            Group {
                switch entry.athanState {
                case .elapsed(let prayer, let mins):
                    HStack {
                        Text("RECENT: +\(mins)m since \(prayer) athan")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.5))
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.05, green: 0.15, blue: 0.1))
                    .cornerRadius(8)
                case .imminent(let prayer, let mins):
                    HStack {
                        Text("IMMINENT: -\(mins)m until \(prayer) athan")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.orange)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.18, green: 0.11, blue: 0.04))
                    .cornerRadius(8)
                case .upcoming(let prayer, let cd):
                    HStack {
                        Text("NEXT: \(prayer) in \(cd)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.cyan)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.08, green: 0.1, blue: 0.15))
                    .cornerRadius(8)
                }
            }
            
            // Prayer List
            VStack(spacing: 4) {
                ForEach(entry.prayers, id: \.name) { p in
                    HStack {
                        Text(p.name)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text(p.arabic)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Spacer()
                        Text(p.timeStr)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(p.name == entry.nextPrayer ? Color.cyan : .white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(14)
    }

    private func miniDay(label: String, temp: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            Text(temp)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(5)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Main Widget Definition
@main
struct StillClockWidget: Widget {
    let kind: String = "StillClockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StillClockProvider()) { entry in
            StillClockWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Still / Clock")
        .description("Jordan prayer times, dynamic athan alerts, and 3-day weather.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
