import Foundation
import Combine

@MainActor
public final class PrayerService: ObservableObject {
    @Published public var prayers: [PrayerItem] = []
    @Published public var alertMode: AthanAlertMode = .none
    @Published public var nextPrayerName: String = ""
    @Published public var nextPrayerCountdownText: String = ""
    @Published public var lastPassedPrayerName: String = ""
    @Published public var lastPassedElapsedText: String = ""
    @Published public var isOfflineCached: Bool = false
    @Published public var lastFetchTime: Date?
    
    private let prayerKeys = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
    private let arabicNames = [
        "Fajr": "الفجر",
        "Dhuhr": "الظهر",
        "Asr": "العصر",
        "Maghrib": "المغرب",
        "Isha": "العشاء"
    ]
    
    private var allUpcomingPrayers: [(name: String, arabic: String, date: Date)] = []
    private var todayPrayers: [(name: String, arabic: String, date: Date)] = []
    
    public init() {
        populateOfflineDefaults()
    }
    
    private func populateOfflineDefaults() {
        guard let ammanTZ = TimeZone(identifier: "Asia/Amman") else { return }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = ammanTZ
        let now = Date()
        
        let defaults: [String: (Int, Int)] = [
            "Fajr": (5, 30),
            "Dhuhr": (12, 20),
            "Asr": (15, 25),
            "Maghrib": (17, 52),
            "Isha": (19, 9)
        ]
        
        var todayMap: [String: String] = [:]
        var tomMap: [String: String] = [:]
        let iso = ISO8601DateFormatter()
        
        for (name, hm) in defaults {
            var comp = cal.dateComponents([.year, .month, .day], from: now)
            comp.hour = hm.0
            comp.minute = hm.1
            comp.second = 0
            comp.timeZone = ammanTZ
            if let d = cal.date(from: comp) {
                todayMap[name] = iso.string(from: d)
            }
            if let tom = cal.date(byAdding: .day, value: 1, to: cal.date(from: comp) ?? now) {
                tomMap[name] = iso.string(from: tom)
            }
        }
        
        self.processTimings(city: JordanCity.allCities[0], todayStr: "default", timingsToday: todayMap, timingsTomorrow: tomMap)
    }
    
    public func fetchPrayers(city: JordanCity) {
        let calendar = Calendar(identifier: .gregorian)
        guard let ammanTZ = TimeZone(identifier: "Asia/Amman") else { return }
        
        let now = Date()
        let df = DateFormatter()
        df.timeZone = ammanTZ
        df.dateFormat = "dd-MM-yyyy"
        
        let todayStr = df.string(from: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let tomorrowStr = df.string(from: tomorrow)
        
        // Load cache first if available
        loadCached(city: city, todayStr: todayStr)
        
        // Fetch Today
        fetchSingleDay(city: city, dateStr: todayStr) { [weak self] timingsToday in
            guard let self = self, let timingsToday = timingsToday else { return }
            
            // Immediately process Today so UI is instant
            self.processTimings(city: city, todayStr: todayStr, timingsToday: timingsToday, timingsTomorrow: nil)
            
            // Then fetch Tomorrow for midnight continuity
            self.fetchSingleDay(city: city, dateStr: tomorrowStr) { [weak self] timingsTomorrow in
                guard let self = self, let timingsTomorrow = timingsTomorrow else { return }
                self.processTimings(city: city, todayStr: todayStr, timingsToday: timingsToday, timingsTomorrow: timingsTomorrow)
            }
        }
    }
    
    private func fetchSingleDay(city: JordanCity, dateStr: String, completion: @escaping ([String: String]?) -> Void) {
        let urlString = "https://api.aladhan.com/v1/timings/\(dateStr)?latitude=\(city.latitude)&longitude=\(city.longitude)&method=23&school=0&timezonestring=Asia%2FAmman&iso8601=true"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataObj = json["data"] as? [String: Any],
                  let timings = dataObj["timings"] as? [String: String] else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            DispatchQueue.main.async {
                completion(timings)
            }
        }.resume()
    }
    
    private func processTimings(city: JordanCity, todayStr: String, timingsToday: [String: String], timingsTomorrow: [String: String]?) {
        // Cache to UserDefaults
        let cacheKey = "stillclock_prayers_\(city.name)_\(todayStr)"
        UserDefaults.standard.set(timingsToday, forKey: cacheKey)
        
        var items: [PrayerItem] = []
        var todayList: [(name: String, arabic: String, date: Date)] = []
        var allList: [(name: String, arabic: String, date: Date)] = []
        
        let isoFormatter = ISO8601DateFormatter()
        let ammanTZ = TimeZone(identifier: "Asia/Amman") ?? .current
        
        let out12 = DateFormatter()
        out12.timeZone = ammanTZ
        out12.dateFormat = "h:mm a"
        
        let out24 = DateFormatter()
        out24.timeZone = ammanTZ
        out24.dateFormat = "HH:mm"
        
        for key in prayerKeys {
            guard let rawTime = timingsToday[key] else { continue }
            // Expected ISO8601 string or "HH:mm"
            var prayerDate: Date? = isoFormatter.date(from: rawTime)
            
            if prayerDate == nil {
                // Parse "HH:mm" relative to today
                let comp = rawTime.components(separatedBy: ":")
                if comp.count >= 2, let h = Int(comp[0].trimmingCharacters(in: .whitespaces)),
                   let m = Int(comp[1].prefix(2).trimmingCharacters(in: .whitespaces)) {
                    var cal = Calendar(identifier: .gregorian)
                    cal.timeZone = ammanTZ
                    var dateComp = cal.dateComponents([.year, .month, .day], from: Date())
                    dateComp.hour = h
                    dateComp.minute = m
                    dateComp.second = 0
                    prayerDate = cal.date(from: dateComp)
                }
            }
            
            if let date = prayerDate {
                let arabic = arabicNames[key] ?? key
                let item = PrayerItem(
                    name: key,
                    arabicName: arabic,
                    date: date,
                    timeFormatted12: out12.string(from: date),
                    timeFormatted24: out24.string(from: date)
                )
                items.append(item)
                todayList.append((name: key, arabic: arabic, date: date))
                allList.append((name: key, arabic: arabic, date: date))
            }
        }
        
        if let tomorrowTimings = timingsTomorrow {
            for key in prayerKeys {
                guard let rawTime = tomorrowTimings[key] else { continue }
                if let date = isoFormatter.date(from: rawTime) {
                    let arabic = arabicNames[key] ?? key
                    allList.append((name: key, arabic: arabic, date: date))
                }
            }
        }
        
        self.prayers = items
        self.todayPrayers = todayList
        self.allUpcomingPrayers = allList
        self.lastFetchTime = Date()
        self.isOfflineCached = false
        
        self.tick()
    }
    
    private func loadCached(city: JordanCity, todayStr: String) {
        let cacheKey = "stillclock_prayers_\(city.name)_\(todayStr)"
        guard let cached = UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: String] else { return }
        self.isOfflineCached = true
        self.processTimings(city: city, todayStr: todayStr, timingsToday: cached, timingsTomorrow: nil)
    }
    
    public func tick() {
        let now = Date()
        
        // 1. Identify the most recent passed prayer for continuous elapsed timer
        var lastPassed: (name: String, diff: TimeInterval)? = nil
        var recentPassed30m: (name: String, diff: TimeInterval)? = nil
        
        let passedPrayers = todayPrayers.filter { now >= $0.date }.sorted { $0.date > $1.date }
        if let latest = passedPrayers.first {
            let diff = now.timeIntervalSince(latest.date)
            lastPassed = (latest.name, diff)
            if diff <= (30 * 60) {
                recentPassed30m = (latest.name, diff)
            }
        }
        
        if let lp = lastPassed {
            self.lastPassedPrayerName = lp.name
            let h = Int(lp.diff) / 3600
            let m = (Int(lp.diff) % 3600) / 60
            let s = Int(lp.diff) % 60
            if h > 0 {
                self.lastPassedElapsedText = String(format: "%dh %02dm %02ds", h, m, s)
            } else {
                self.lastPassedElapsedText = String(format: "%02dm %02ds", m, s)
            }
        }
        
        // 2. Find next upcoming prayer
        let upcoming = allUpcomingPrayers.filter { $0.date > now }.sorted { $0.date < $1.date }
        let nextPrayer = upcoming.first
        
        if let next = nextPrayer {
            let remaining = next.date.timeIntervalSince(now)
            self.nextPrayerName = next.name
            
            let hours = Int(remaining) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            let seconds = Int(remaining) % 60
            
            if hours > 0 {
                self.nextPrayerCountdownText = String(format: "%dh %02dm %02ds", hours, minutes, seconds)
            } else {
                self.nextPrayerCountdownText = String(format: "%02dm %02ds", minutes, seconds)
            }
            
            // If within 25 minutes before athan (0 <= remaining <= 1500s)
            if remaining <= (25 * 60) {
                self.alertMode = .imminent(prayer: next.name, secondsRemaining: remaining)
                return
            }
        } else {
            self.nextPrayerName = "Tomorrow"
            self.nextPrayerCountdownText = "Calculating..."
        }
        
        // If within 30 minutes after last prayer, show dynamic elapsed alert
        if let recent = recentPassed30m {
            self.alertMode = .elapsed(prayer: recent.name, secondsPassed: recent.diff)
            return
        }
        
        // Standard countdown & elapsed state (always shows both elapsed and countdown)
        if let next = nextPrayer {
            let remaining = next.date.timeIntervalSince(now)
            self.alertMode = .standard(prayer: next.name, secondsRemaining: remaining)
        } else {
            self.alertMode = .none
        }
    }
}
