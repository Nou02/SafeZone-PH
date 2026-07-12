## SafeZone PH - Flutter

A starter Flutter application for SafeZone PH with core navigation and placeholder screens.

### Run locally

1. Install Flutter (stable) and required platforms (Android/iOS/web).
2. From the project directory:

```bash
flutter pub get
flutter run
```

### App structure

- `lib/main.dart`: App entry, theme, and routes
- `lib/screens/main_shell.dart`: Bottom navigation with 5 tabs
- `lib/screens/tabs/*`: Placeholder screens for Home, Report, Map, Resources, Profile
- `lib/screens/onboarding_screen.dart`, `lib/screens/login_screen.dart`: Auth flow placeholders

### Dependencies

- `provider`: state management
- `http`: network requests
- `geolocator`: location access
- `google_maps_flutter`: map view (requires API key)

### Next steps

- Add your Google Maps API key for Android/iOS before using the map:
  - Android: set `com.google.android.geo.API_KEY` in `android/app/src/main/AndroidManifest.xml`
  - iOS: provide the key in `AppDelegate.swift` using `GMSServices.provideAPIKey("KEY")`. Also ensure `NSLocationWhenInUseUsageDescription` exists in `Info.plist` (already added).
  - Web: supply the Maps JavaScript API key via `--dart-define=GOOGLE_MAPS_API_KEY=KEY` and configure as needed for `google_maps_flutter_web`.

Permissions:
- Android location permissions are added in `AndroidManifest.xml`.
- iOS usage description is added in `Info.plist`.

OpenStreetMap (no key required)
- We switched the Create Report map to `flutter_map` with OSM tiles.
- Respect OSM tile fair-use policy for production; consider a tile provider (MapTiler, Stadia, etc.) if you expect higher traffic.
- Replace placeholder screens with real features and data
- Add app icon/branding (e.g., via `flutter_launcher_icons`)

### Package identifiers

- Android/iOS package: `com.safezoneph.safezone_ph`

# safezone_ph

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
