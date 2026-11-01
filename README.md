# StillClock for iOS 🕰️

A minimalist clock, Jordan prayer times, and 3-day weather dashboard designed for iOS, converted from the Tizen OS StillClock concept.

## Features

- **Iconic Developer Aesthetic**: Deep dark theme, `const now =` layout, brackets, monospaced typography, and glowing status dots.
- **Jordan Prayer Times (Method 23 - Awqaf)**:
  - Supports Jordan cities: Amman, Irbid, Zarqa, Aqaba, Salt, Madaba, Karak, Jerash, Ajloun, Mafraq, Tafilah, Maan.
  - Powered by Aladhan API with offline cache fallbacks.
  - 5 prayers (Fajr, Dhuhr, Asr, Maghrib, Isha) with Arabic typography and relative countdowns.
- **Dynamic Athan Indicator Widget**:
  - **Within 30 minutes after athan**: Automatically triggers `ATHAN RECENT (+30m)` showing exact elapsed time (`+14m 20s since [Prayer] athan`).
  - **Within 10 minutes before athan**: Automatically triggers `ATHAN IMMINENT (-10m)` showing live countdown (`-08m 15s until [Prayer] athan`).
  - **Standard**: Displays upcoming prayer and countdown (`NEXT / MAGHRIB IN 02h 15m 30s`).
- **Next 3-Days Weather Widget**:
  - Live 3-day forecast for Jordan (Today, Tomorrow, After Tomorrow).
  - High & low temperatures in °C.
  - Condition summary & SF Symbols (Clear, Cloudy, Rain, etc.).
  - Precipitation probability percentages.
- **Preferences & Settings**:
  - Switch between 12-hour and 24-hour time.
  - Toggle seconds display.
  - Change Jordan city location anytime.

## How to Build the `.ipa` via GitHub Actions

1. Create a new GitHub repository (e.g. `StillClockApp`).
2. Push this directory to your repository:
   ```bash
   git init
   git add .
   git commit -m "Initial StillClock iOS project"
   git branch -M main
   git remote add origin https://github.com/<YOUR_USERNAME>/StillClockApp.git
   git push -u origin main
   ```
3. GitHub Actions will trigger automatically under the **Actions** tab.
4. Once completed, download `StillClock-ipa` from Artifacts, extract `StillClock.ipa`, and sideload it to your iPhone using Sideloadly or AeroLoad!

