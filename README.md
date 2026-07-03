# Olilo Status

Olilo Status the open source status app for the Olilo ISP in the UK & Ireland. It gives the community a fast, live view of network health, active incidents, planned maintenance, historical notices, and support links across iOS and Android platforms.

## Screenshots

### iOS

<p>
  <img src="App%20Store/olilo-ios-1.png" width="180" alt="Olilo Status iOS screenshot 1">
  <img src="App%20Store/olilo-ios-2.png" width="180" alt="Olilo Status iOS screenshot 2">
  <img src="App%20Store/olilo-ios-3.png" width="180" alt="Olilo Status iOS screenshot 3">
  <img src="App%20Store/olilo-ios-4.png" width="180" alt="Olilo Status iOS screenshot 4">
</p>

### Android

<p>
  <img src="Play%20Store/olilo-android-1.png" width="180" alt="Olilo Status Android screenshot 1">
  <img src="Play%20Store/olilo-android-2.png" width="180" alt="Olilo Status Android screenshot 2">
  <img src="Play%20Store/olilo-android-3.png" width="180" alt="Olilo Status Android screenshot 3">
  <img src="Play%20Store/olilo-android-4.png" width="180" alt="Olilo Status Android screenshot 4">
</p>

## Features

- Live overview of the Olilo Network.
- Service and component health grouped by status.
- Push Notification for Network Alerts
- Active incident and maintenance cards with direct links to status updates.
- Notice history with filters for incidents and maintenance.
- Direct contact links for the Olilo Teams official Discord and Reddit channels.
- iOS & Android home screen widget showing whether the Olilo network is online (choose your network Openreach, CityFibre & Freedom Fibre).
- Native SwiftUI iOS app and native Kotlin/Jetpack Compose Android app.

## Repository

This repository contains the source for Olilo Status. The project is public so users can inspect how the app works, report issues, propose improvements, and build their own local copy.

Current app areas include:

- `iOS/Olilo Status` - SwiftUI iOS app.
- `iOS/Olilo Status Widget` - WidgetKit extension.
- `android` - Kotlin/Jetpack Compose Android app.
- `android/app/src/main/java/uk/co/olilo/status/widget` - WidgetProvider.
- `Backend` - Node.js push-notification service (APNs + FCM).
- `App Store` - iOS screenshots and store assets.
- `Play Store` - Android screenshots and store assets.

## Notifications

Push notifications are delivered by the Node.js service in `Backend`, which polls
the Olilo status page and pushes incident, maintenance, and component alerts to
iOS (APNs) and Android (FCM). See [`NOTIFICATIONS.md`](NOTIFICATIONS.md) for a
developer overview, or `Backend/README.md` and `Backend/CLIENTS.md` for the
service and client-integration details.

## iOS Development

Requirements:

- Xcode 26.0+

To work on the iOS app:

1. Open `iOS/Olilo Status.xcodeproj` in Xcode.
2. Select the `Olilo Status` scheme.
3. Build and run the app on a simulator or device.

## Android Development

Requirements:

- Android Studio
- JDK 17
- Android SDK matching the project configuration

To work on the Android app:

1. Open the `android` directory in Android Studio.
2. Let Gradle sync the `OliloStatusAndroid` project.
3. Run the `app` configuration on an emulator or device.

From the command line, you can build a debug APK with:

```sh
cd android
./gradlew :app:assembleDebug
```

The Android app package is `uk.co.olilo.status` and uses Kotlin, Jetpack Compose, Material 3, Navigation Compose, coroutines, and Kotlin serialization.

## Contributing

Contributions are welcome. Keep changes focused, follow the existing project structure, and include enough context in merge requests for reviewers to understand the behavior change.

Useful areas for contributions include:

- Accessibility improvements.
- Feature additions
- Documentation updates.
- Bug reports with device, OS version, and reproduction steps.

After contributing a set amount to the project, you'll be added to the contributors list.

(For privacy reasons, this will be on request only)

## Support and Community

- GitLab: https://gitlab.com/team-olilo/status-app
- Discord: https://discord.gg/olilo
- Reddit: https://www.reddit.com/r/Olilo
- Olilo: https://olilo.co.uk

## License

Olilo Status is open source under the GNU General Public License v3.0. See `LICENSE` for the full license text.
