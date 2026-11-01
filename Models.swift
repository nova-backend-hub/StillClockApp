import Foundation

public struct JordanCity: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let latitude: Double
    public let longitude: Double
    
    public init(name: String, latitude: Double, longitude: Double) {
        self.id = name
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
    
    public static let allCities: [JordanCity] = [
        JordanCity(name: "Amman", latitude: 31.9539, longitude: 35.9106),
        JordanCity(name: "Irbid", latitude: 32.5556, longitude: 35.8500),
        JordanCity(name: "Zarqa", latitude: 32.0728, longitude: 36.0880),
        JordanCity(name: "Aqaba", latitude: 29.5321, longitude: 35.0063),
        JordanCity(name: "Salt", latitude: 32.0392, longitude: 35.7272),
        JordanCity(name: "Madaba", latitude: 31.7167, longitude: 35.8000),
        JordanCity(name: "Karak", latitude: 31.1853, longitude: 35.7047),
        JordanCity(name: "Mafraq", latitude: 32.3429, longitude: 36.2080),
        JordanCity(name: "Jerash", latitude: 32.2747, longitude: 35.8961),
        JordanCity(name: "Ajloun", latitude: 32.3333, longitude: 35.7528),
        JordanCity(name: "Tafilah", latitude: 30.8375, longitude: 35.6044),
        JordanCity(name: "Maan", latitude: 30.1949, longitude: 35.7342)
    ]
}

public struct PrayerItem: Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let arabicName: String
    public let date: Date
    public let timeFormatted12: String
    public let timeFormatted24: String
}

public enum AthanAlertMode {
    case elapsed(prayer: String, secondsPassed: TimeInterval)   // within 30 mins after athan
    case imminent(prayer: String, secondsRemaining: TimeInterval) // within 10 mins before athan
    case standard(prayer: String, secondsRemaining: TimeInterval) // general upcoming
    case none
}

public struct WeatherDay: Identifiable {
    public let id = UUID()
    public let label: String          // "Today", "Tomorrow", "After Tomorrow"
    public let date: Date
    public let maxTemp: Int
    public let minTemp: Int
    public let condition: String
    public let iconSymbol: String
    public let precipitationChance: Int
}
