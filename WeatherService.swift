import Foundation
import Combine

@MainActor
public final class WeatherService: ObservableObject {
    @Published public var forecast: [WeatherDay] = []
    @Published public var isLoading: Bool = false
    @Published public var lastUpdated: String = ""
    @Published public var errorMessage: String? = nil
    
    public init() {}
    
    public func fetchWeather(city: JordanCity) {
        isLoading = true
        errorMessage = nil
        
        // Check cache first
        let cacheKey = "stillclock_weather_\(city.name)"
        if let cachedData = UserDefaults.standard.data(forKey: cacheKey),
           let cachedDays = try? JSONDecoder().decode([CachedWeatherDay].self, from: cachedData) {
            self.forecast = cachedDays.map { $0.toWeatherDay() }
        }
        
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(city.latitude)&longitude=\(city.longitude)&daily=weathercode,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=Asia%2FAmman"
        guard let url = URL(string: urlStr) else {
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let daily = json["daily"] as? [String: Any],
                  let dates = daily["time"] as? [String],
                  let codes = daily["weathercode"] as? [Int],
                  let maxTemps = daily["temperature_2m_max"] as? [Double],
                  let minTemps = daily["temperature_2m_min"] as? [Double] else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to parse weather"
                }
                return
            }
            
            let precipProbs = (daily["precipitation_probability_max"] as? [Int]) ?? [0, 0, 0]
            
            var result: [WeatherDay] = []
            var cachePayload: [CachedWeatherDay] = []
            let labels = ["Today", "Tomorrow", "After Tomorrow"]
            
            let isoFormatter = DateFormatter()
            isoFormatter.dateFormat = "yyyy-MM-dd"
            isoFormatter.timeZone = TimeZone(identifier: "Asia/Amman")
            
            let count = min(3, dates.count)
            for i in 0..<count {
                let date = isoFormatter.date(from: dates[i]) ?? Date()
                let code = codes[i]
                let maxT = Int(round(maxTemps[i]))
                let minT = Int(round(minTemps[i]))
                let prob = precipProbs.indices.contains(i) ? precipProbs[i] : 0
                
                let (condition, symbol) = self.interpretWeatherCode(code)
                let label = i < labels.count ? labels[i] : dates[i]
                
                let day = WeatherDay(
                    label: label,
                    date: date,
                    maxTemp: maxT,
                    minTemp: minT,
                    condition: condition,
                    iconSymbol: symbol,
                    precipitationChance: prob
                )
                result.append(day)
                cachePayload.append(CachedWeatherDay(
                    label: label,
                    date: date,
                    maxTemp: maxT,
                    minTemp: minT,
                    condition: condition,
                    iconSymbol: symbol,
                    precipitationChance: prob
                ))
            }
            
            // Save cache
            if let encoded = try? JSONEncoder().encode(cachePayload) {
                UserDefaults.standard.set(encoded, forKey: cacheKey)
            }
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            timeFormatter.timeZone = TimeZone(identifier: "Asia/Amman")
            let updateTimeStr = timeFormatter.string(from: Date())
            
            DispatchQueue.main.async {
                self.forecast = result
                self.lastUpdated = updateTimeStr
            }
        }.resume()
    }
    
    private func interpretWeatherCode(_ code: Int) -> (condition: String, symbol: String) {
        switch code {
        case 0:
            return ("Clear sky", "sun.max.fill")
        case 1:
            return ("Mainly clear", "sun.haze.fill")
        case 2:
            return ("Partly cloudy", "cloud.sun.fill")
        case 3:
            return ("Overcast", "cloud.fill")
        case 45, 48:
            return ("Foggy", "cloud.fog.fill")
        case 51, 53, 55:
            return ("Drizzle", "cloud.drizzle.fill")
        case 61, 63:
            return ("Slight rain", "cloud.rain.fill")
        case 65:
            return ("Heavy rain", "cloud.heavyrain.fill")
        case 71, 73, 75, 77:
            return ("Snow", "snowflake")
        case 80, 81, 82:
            return ("Rain showers", "cloud.sun.rain.fill")
        case 85, 86:
            return ("Snow showers", "cloud.snow.fill")
        case 95, 96, 99:
            return ("Thunderstorm", "cloud.bolt.rain.fill")
        default:
            return ("Fair", "cloud.sun.fill")
        }
    }
}

private struct CachedWeatherDay: Codable {
    let label: String
    let date: Date
    let maxTemp: Int
    let minTemp: Int
    let condition: String
    let iconSymbol: String
    let precipitationChance: Int
    
    func toWeatherDay() -> WeatherDay {
        WeatherDay(
            label: label,
            date: date,
            maxTemp: maxTemp,
            minTemp: minTemp,
            condition: condition,
            iconSymbol: iconSymbol,
            precipitationChance: precipitationChance
        )
    }
}
