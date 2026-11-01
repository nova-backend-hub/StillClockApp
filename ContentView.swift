import SwiftUI

struct ContentView: View {
    @StateObject private var prayerService = PrayerService()
    @StateObject private var weatherService = WeatherService()
    
    @AppStorage("selectedCityName") private var selectedCityName: String = "Amman"
    @AppStorage("is24HourFormat") private var is24HourFormat: Bool = false
    @AppStorage("showSeconds") private var showSeconds: Bool = true
    
    @State private var currentDate = Date()
    @State private var showSettings = false
    
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var currentCity: JordanCity {
        JordanCity.allCities.first(where: { $0.name == selectedCityName }) ?? JordanCity.allCities[0]
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.05, green: 0.05, blue: 0.07)
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    headerView
                    clockCompositionView
                    dynamicAthanWidget
                    weatherSectionView
                    prayerCardsSectionView
                    footerView
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            settingsSheetView
        }
        .onAppear {
            refreshAllData()
        }
        .onReceive(timer) { input in
            currentDate = input
            prayerService.tick()
        }
        .onChange(of: selectedCityName) { _ in
            refreshAllData()
        }
    }
    
    private func refreshAllData() {
        prayerService.fetchPrayers(city: currentCity)
        weatherService.fetchWeather(city: currentCity)
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Text("still")
                    .font(.system(size: 19, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("/")
                    .font(.system(size: 18, weight: .light, design: .monospaced))
                    .foregroundColor(Color.gray.opacity(0.6))
                Text("clock")
                    .font(.system(size: 19, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(red: 0.8, green: 0.85, blue: 0.9))
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                    .shadow(color: Color.green.opacity(0.8), radius: 4)
                
                Text("LOCAL TIME")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.gray.opacity(0.9))
                
                Button(action: { showSettings = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.gray.opacity(0.8))
                        .padding(6)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.top, 6)
    }
    
    // MARK: - StillClock Main Composition
    private var clockCompositionView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("// a little room for the present")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(Color(red: 0.35, green: 0.7, blue: 0.55))
            
            // Time digits
            VStack(alignment: .leading, spacing: 4) {
                Text("const now =")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.gray)
                
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(timeHoursString)
                        .font(.system(size: 58, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text(":")
                        .font(.system(size: 52, weight: .light, design: .monospaced))
                        .foregroundColor(Color.gray.opacity(0.8))
                    
                    Text(timeMinutesString)
                        .font(.system(size: 58, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    if showSeconds {
                        Text(":")
                            .font(.system(size: 28, weight: .light, design: .monospaced))
                            .foregroundColor(Color.gray.opacity(0.5))
                            .padding(.leading, 2)
                        
                        Text(timeSecondsString)
                            .font(.system(size: 28, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(red: 0.4, green: 0.85, blue: 0.95))
                    }
                    
                    if !is24HourFormat {
                        Text(timePeriodString)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.gray)
                            .padding(.leading, 6)
                    }
                }
            }
            
            // Date block with brackets
            HStack(spacing: 8) {
                Text("{")
                    .font(.system(size: 24, weight: .light, design: .monospaced))
                    .foregroundColor(Color.gray.opacity(0.6))
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("today: \(dateWeekdayString), \(dateDayMonthYearString)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(red: 0.85, green: 0.88, blue: 0.92))
                }
                
                Text("}")
                    .font(.system(size: 24, weight: .light, design: .monospaced))
                    .foregroundColor(Color.gray.opacity(0.6))
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            HStack {
                Text("Take your time.")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(Color.gray.opacity(0.85))
                
                Spacer()
                
                Text("\(currentCity.name.uppercased()) / ASIA.AMMAN")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.45, green: 0.75, blue: 0.65))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.09, green: 0.09, blue: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Dynamic Athan Indicator Widget
    private var dynamicAthanWidget: some View {
        Group {
            switch prayerService.alertMode {
            case .elapsed(let prayer, let secondsPassed):
                // Within 30 minutes after athan
                let mins = Int(secondsPassed) / 60
                let secs = Int(secondsPassed) % 60
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.5))
                            .font(.system(size: 16, weight: .bold))
                        
                        Text("ATHAN RECENT // +30 MIN WINDOW")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.5))
                        
                        Spacer()
                        
                        Text("POST-ATHAN")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.2, green: 0.9, blue: 0.5).opacity(0.2))
                            .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.5))
                            .cornerRadius(4)
                    }
                    
                    HStack(alignment: .firstTextBaseline) {
                        Text(String(format: "+%02dm %02ds", mins, secs))
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text("since \(prayer) athan")
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(red: 0.8, green: 0.9, blue: 0.85))
                    }
                    
                    Text("Time elapsed after athan up until 30 minutes threshold")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(Color.gray.opacity(0.8))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(red: 0.05, green: 0.15, blue: 0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(red: 0.2, green: 0.9, blue: 0.5).opacity(0.4), lineWidth: 1.5)
                        )
                )
                
            case .imminent(let prayer, let secondsRemaining):
                // Within 10 minutes before athan
                let mins = Int(secondsRemaining) / 60
                let secs = Int(secondsRemaining) % 60
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.15))
                            .font(.system(size: 16, weight: .bold))
                        
                        Text("ATHAN IMMINENT // -10 MIN COUNTDOWN")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.15))
                        
                        Spacer()
                        
                        Text("UPCOMING")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 1.0, green: 0.65, blue: 0.15).opacity(0.2))
                            .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.15))
                            .cornerRadius(4)
                    }
                    
                    HStack(alignment: .firstTextBaseline) {
                        Text(String(format: "-%02dm %02ds", mins, secs))
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text("until \(prayer) athan")
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.6))
                    }
                    
                    Text("Countdown active down until 0 for impending prayer")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(Color.gray.opacity(0.8))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(red: 0.18, green: 0.11, blue: 0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(red: 1.0, green: 0.65, blue: 0.15).opacity(0.5), lineWidth: 1.5)
                        )
                )
                
            case .standard(let prayer, _):
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.95))
                            .font(.system(size: 14))
                        
                        Text("NEXT / \(prayer.uppercased())")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("IN \(prayerService.nextPrayerCountdownText)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.95))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.08, green: 0.1, blue: 0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
                
            case .none:
                EmptyView()
            }
        }
    }
    
    // MARK: - Next 3 Days Weather Widget
    private var weatherSectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("LOOKING AHEAD /")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.gray)
                
                Text("NEXT THREE DAYS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.4, green: 0.75, blue: 0.95))
                
                Spacer()
                
                if !weatherService.lastUpdated.isEmpty {
                    Text("UPDATED \(weatherService.lastUpdated)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.gray.opacity(0.7))
                }
            }
            
            if weatherService.forecast.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(Color.cyan)
                        .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                HStack(spacing: 10) {
                    ForEach(weatherService.forecast) { day in
                        weatherDayCard(day)
                    }
                }
            }
        }
    }
    
    private func weatherDayCard(_ day: WeatherDay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(day.label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color.gray.opacity(0.85))
            
            HStack(spacing: 6) {
                Image(systemName: day.iconSymbol)
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.3))
                
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(day.maxTemp)°")
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("/\(day.minTemp)°C")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.gray)
                }
            }
            
            Text(day.condition)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color(red: 0.8, green: 0.85, blue: 0.9))
                .lineLimit(1)
            
            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 9))
                    .foregroundColor(Color.cyan)
                Text("\(day.precipitationChance)%")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.cyan.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.09, blue: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Jordan Prayer Times Section
    private var prayerCardsSectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(currentCity.name.uppercased()) / JORDAN")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white)
                
                Spacer()
                
                Text("ALADHAN · METHOD 23")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.gray.opacity(0.7))
            }
            
            VStack(spacing: 8) {
                ForEach(prayerService.prayers) { item in
                    prayerCardRow(item)
                }
            }
        }
    }
    
    private func prayerCardRow(_ item: PrayerItem) -> some View {
        let isNext = (item.name == prayerService.nextPrayerName)
        let isPast = currentDate > item.date
        
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text(item.arabicName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.gray.opacity(0.85))
                }
                
                if isPast {
                    let diff = currentDate.timeIntervalSince(item.date)
                    let mins = Int(diff) / 60
                    if mins < 60 {
                        Text("+ \(mins)m since athan")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(red: 0.4, green: 0.8, blue: 0.6))
                    } else {
                        Text("Today · Asia/Amman")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(Color.gray.opacity(0.6))
                    }
                } else {
                    let remaining = item.date.timeIntervalSince(currentDate)
                    let hrs = Int(remaining) / 3600
                    let mins = (Int(remaining) % 3600) / 60
                    let timeText = hrs > 0 ? "In \(hrs)h \(mins)m" : "In \(mins)m"
                    Text(timeText)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(isNext ? Color(red: 0.4, green: 0.75, blue: 0.95) : Color.gray.opacity(0.6))
                }
            }
            
            Spacer()
            
            Text(is24HourFormat ? item.timeFormatted24 : item.timeFormatted12)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(isNext ? Color(red: 0.4, green: 0.8, blue: 0.95) : .white)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isNext ? Color(red: 0.1, green: 0.13, blue: 0.18) : Color(red: 0.08, green: 0.08, blue: 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isNext ? Color.cyan.opacity(0.4) : Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Footer
    private var footerView: some View {
        HStack {
            Text("DESIGNED TO SLOW THINGS DOWN.")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color.gray.opacity(0.5))
            
            Spacer()
            
            Text("v1.0")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(Color.gray.opacity(0.4))
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Settings Sheet
    private var settingsSheetView: some View {
        NavigationView {
            Form {
                Section(header: Text("City / Location in Jordan")) {
                    Picker("Select City", selection: $selectedCityName) {
                        ForEach(JordanCity.allCities) { city in
                            Text(city.name).tag(city.name)
                        }
                    }
                }
                
                Section(header: Text("Clock Preferences")) {
                    Toggle("24-Hour Format", isOn: $is24HourFormat)
                    Toggle("Show Seconds", isOn: $showSeconds)
                }
                
                Section(header: Text("Athan Indicator Rules")) {
                    Text("• Up to 30 mins after athan: Shows elapsed time (+Xm since athan).")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("• Down to 10 mins before athan: Shows imminent countdown (-Xm until athan).")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button(action: {
                        refreshAllData()
                        showSettings = false
                    }) {
                        HStack {
                            Spacer()
                            Text("Refresh Data Now")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showSettings = false
                    }
                }
            }
        }
    }
    
    // MARK: - Date / Time Formatting Helpers
    private var timeHoursString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = is24HourFormat ? "HH" : "hh"
        return formatter.string(from: currentDate)
    }
    
    private var timeMinutesString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "mm"
        return formatter.string(from: currentDate)
    }
    
    private var timeSecondsString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ss"
        return formatter.string(from: currentDate)
    }
    
    private var timePeriodString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter.string(from: currentDate)
    }
    
    private var dateWeekdayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: currentDate)
    }
    
    private var dateDayMonthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: currentDate)
    }
}
