# NightsunTV

A high-performance, dark-themed IPTV live streaming application built with Flutter.

NightsunTV aggregates thousands of publicly available, free-to-air live television channels into an intuitive, pure-black interface crafted for late-night viewing and seamless channel navigation.

---

## ✨ Features

- **Massive Channel Catalog**: Over 15,200+ free live channels and 25,700+ stream mirrors across 184 countries.
- **Multi-Source Aggregation**: Merged catalog from Samsung TV Plus, Pluto TV, Free-TV, Plex TV, Tubi TV, and IPTV-org.
- **True Dark & OLED Themes**: Designed specifically for low-light environments with Pure Black, Midnight, Slate, and Nebula themes alongside custom accent colors.
- **Automatic Stream Failover**: If a stream mirror stutters or disconnects, the player automatically falls back to secondary mirrors without disrupting playback.
- **Live Lineup Refresh**: Sync fresh stream mirrors on-demand directly from the public IPTV-org playlist with intelligent mirror merging.
- **Offline Snapshot**: Bundled offline catalog ensures instant startup with zero network lag on cold boot.
- **Lightning Search**: Sub-millisecond accent-folded search across channel titles, network names, countries, and categories.
- **Personal Library**: Bookmark your favorite channels and access recent channels with persistent local storage.

---

## 🛠️ Tech Stack & Architecture

- **Framework**: [Flutter](https://flutter.dev) (Dart)
- **State Management**: [Riverpod](https://riverpod.dev)
- **Video Engine**: Official `video_player` with hardware acceleration and adaptive aspect ratio support
- **Architecture**: Feature-first clean structure with distinct data, state, and presentation layers

### Directory Overview

```text
lib/
├── core/         # Theme palettes, pressable controls, starfield canvas, helpers
├── data/         # Catalog repository, models, and IPTV M3U parser/refresh service
├── features/     # UI screens (Home, Browse, Search, Player, Library, Settings)
└── state/        # Riverpod providers, playback controller, settings notifier
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>= 3.20.0)
- Android SDK (API 24 or newer, compileSdk 37)
- JDK 17

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Srijan-Banerjee/NightsunTV.git
   cd NightsunTV
   ```

2. Fetch Flutter packages:
   ```bash
   flutter pub get
   ```

3. Run static analysis and unit tests:
   ```bash
   flutter analyze
   flutter test
   ```

4. Launch the application:
   ```bash
   flutter run
   ```

### Building Release APK

To build a release APK for Android:

```bash
flutter build apk --release --target-platform android-arm64
```

The resulting APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.

*(Optional)* To sign with your own release keystore, copy `android/key.properties.example` to `android/key.properties` and provide your keystore credentials. If omitted, the build automatically uses debug signing for local testing.

---

## 🤝 Contributing

Contributions, bug reports, and suggestions are welcome! Feel free to open an issue or submit a pull request.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License & Disclaimer

- **License**: Distributed under the MIT License.
- **Disclaimer**: NightsunTV is an open-source media player. It does not host, distribute, or stream any proprietary content. All channel metadata and streams are aggregated from public, freely available sources.
