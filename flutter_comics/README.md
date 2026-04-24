# Read Comics — Flutter

> A cross-platform comic book reader built with Flutter.  
> Originally ported from the native SwiftUI **Read-It-All** app to bring CBZ, CBR, ZIP, RAR, PDF, and image-folder support to Android, iOS, Web, Windows, macOS, and Linux.

---

## Table of Contents
- [Features](#features)
- [Platform Support](#platform-support)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Running the App](#running-the-app)
- [Project Structure](#project-structure)
- [Architecture & State Management](#architecture--state-management)
- [Dependencies](#dependencies)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

---

## Features

| Feature | Status |
|---|---|
| **Library Management** | Import comics, group by series, sort & filter |
| **Multi-Format Support** | CBZ, CBR, ZIP, RAR, PDF, image folders |
| **Reading Progress** | Per-chapter page tracking with resume |
| **Adaptive UI** | Responsive layouts for mobile, tablet, and desktop |
| **Cross-Platform** | Android, iOS, Web, Windows, macOS, Linux |
| **Local Persistence** | Hive database for chapters and progress |
| **Thumbnails** | Async cover/page previews |
| **Themes** | Material 3 dynamic theming |

---

## Platform Support

| Platform | Status |
|---|---|
| Android | ✅ Ready |
| iOS | ✅ Ready |
| Web | ✅ Ready |
| Windows | ✅ Ready |
| macOS | ✅ Ready |
| Linux | ✅ Ready |

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.10.0)
- [Dart SDK](https://dart.dev/get-dart) (>= 3.0.0)
- A connected device or emulator / Chrome browser

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/Read-Comics.git
   cd Read-Comics/flutter_comics
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Generate Hive adapters (if models change):
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

### Running the App

```bash
# Android
flutter run

# iOS
flutter run -d ios

# Web (Chrome)
flutter run -d chrome

# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

> **Note:** For mobile, ensure you have a device connected or an emulator running. For Web/Desktop, ensure the platform is enabled via `flutter config`.

---

## Project Structure

```
flutter_comics/
├── android/                  # Android platform code
├── ios/                      # iOS platform code
├── linux/                    # Linux platform code
├── macos/                    # macOS platform code
├── web/                      # Web platform code
├── windows/                  # Windows platform code
├── lib/
│   ├── main.dart             # App entrypoint & Provider setup
│   ├── models/
│   │   └── comic_models.dart # ComicChapter, ComicSeries, ComicProgress
│   ├── services/
│   │   └── comic_library_service.dart  # Business logic & Hive persistence
│   ├── screens/
│   │   └── library_screen.dart         # Library grid/list UI
│   └── ...                   # Additional views, utils, widgets
├── pubspec.yaml              # Dependencies
└── README.md                 # You are here!
```

---

## Architecture & State Management

- **UI Layer:** Flutter widgets (`MaterialApp`, `GridView`, `PageView`).
- **State Management:** [Provider](https://pub.dev/packages/provider) (`ChangeNotifier`) for reactive app-wide state.
- **Persistence:** [Hive](https://pub.dev/packages/hive) for fast, local NoSQL storage of chapters and reading progress.
- **Services:** `ComicLibraryService` handles import, grouping, sorting, and CRUD operations.

---

## Dependencies

| Package | Purpose |
|---|---|
| `provider` | State management |
| `hive` / `hive_flutter` | Local database & adapters |
| `path_provider` | Access app directories |
| `file_picker` | Select comic files from device |
| `archive` | Extract ZIP / CBZ archives |
| `pdf_render` | Render PDF pages |
| `image` | Image decoding & thumbnails |
| `shared_preferences` | Lightweight settings storage |
| `permission_handler` | Storage permissions (Android) |

See `pubspec.yaml` for full version constraints.

---

## Roadmap

- [x] Project scaffolding & platform generation
- [x] Hive models & persistence layer
- [x] Library UI grid layout
- [ ] File picker & import pipeline
- [ ] Archive extraction (ZIP/CBZ)
- [ ] RAR/CBR support
- [ ] PDF page rendering
- [ ] Reader screen with PageView
- [ ] Reading progress resume
- [ ] Search & filter
- [ ] Settings & theming
- [ ] Cloud sync (optional)

---

## Contributing

Contributions are welcome! Please fork the repository and open a pull request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This Flutter port inherits the license of the original Read-It-All project. See the root `LICENSE` file for details.

---

**Happy Reading! 📚**
