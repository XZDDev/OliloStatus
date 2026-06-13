# Client integration guide

How to wire the iOS and Android apps to the notifications backend. Both
platforms follow the same flow:

1. User opts in -> request OS notification permission.
2. Obtain the platform push token (APNs / FCM).
3. `POST /api/devices/register` with the token + preferences.
4. Re-register whenever the token rotates; `PATCH` when preferences change.

The backend handles everything else (targeting, delivery, pruning dead tokens).
Set the backend URL - and `API_KEY` if the server has one - in each platform's
config (`OliloNotificationConfig` on iOS, `OliloNotifications` on Android).

---

## iOS

Drop-in files (add both to the `Olilo Status` target):

- `iOS/Olilo Status/Notifications/OliloNotifications.swift` - API client, prefs, push manager, app delegate.
- `iOS/Olilo Status/Notifications/NotificationSettingsView.swift` - optional settings screen.

### 1. Enable the capability

Target -> **Signing & Capabilities** -> **+ Capability** -> **Push Notifications**.

### 2. Set the backend URL

In `OliloNotifications.swift`:

```swift
enum OliloNotificationConfig {
    static let baseURL = URL(string: "https://notifications.example.com")!
    static let apiKey: String? = nil   // set if the backend uses API_KEY
}
```

### 3. Attach the app delegate

In `Olilo.swift`:

```swift
@main
struct Olilo_StatusApp: App {
    @UIApplicationDelegateAdaptor(PushAppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

### 4. Let the user opt in

Add a link from the existing Settings screen:

```swift
NavigationLink("Notifications") { NotificationSettingsView() }
```

The bundled view calls `PushManager.shared.enableNotifications()`, which requests
permission, registers for APNs, and posts the token to the backend. Preference
toggles sync automatically. To drive it yourself instead:

```swift
await PushManager.shared.enableNotifications()
await PushManager.shared.updatePreferences(prefs)
await PushManager.shared.disableNotifications()
```

> Test pushes on a real device - the iOS Simulator does not receive APNs. Use the
> **sandbox** backend (`APNS_PRODUCTION=false`) for development/TestFlight builds.

---

## Android

Drop-in files (already under `uk.co.olilo.status.notifications`):

- `NotificationPreferences.kt` - prefs model + storage.
- `OliloNotifications.kt` - opt-in/out + backend client.
- `OliloMessagingService.kt` - FCM service (token rotation + incoming pushes).

These depend on Firebase Cloud Messaging, which needs a small amount of setup.

### 1. Add Firebase to the project

Create a Firebase project, add an Android app with package `uk.co.olilo.status`,
and drop the generated **`google-services.json`** into `android/app/`.

### 2. Gradle

Root `android/build.gradle.kts`:

```kotlin
plugins {
    // ...existing...
    id("com.google.gms.google-services") version "4.4.2" apply false
}
```

`android/app/build.gradle.kts`:

```kotlin
plugins {
    // ...existing...
    id("com.google.gms.google-services")
}

dependencies {
    // ...existing...
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-messaging")
}
```

### 3. Manifest

In `android/app/src/main/AndroidManifest.xml`, add the permission and service:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<application ...>
    <!-- ...existing... -->
    <service
        android:name=".notifications.OliloMessagingService"
        android:exported="false">
        <intent-filter>
            <action android:name="com.google.firebase.MESSAGING_EVENT" />
        </intent-filter>
    </service>
</application>
```

### 4. Set the backend URL

In `OliloNotifications.kt`:

```kotlin
const val BASE_URL = "https://notifications.example.com"
val API_KEY: String? = null   // set if the backend uses API_KEY
```

### 5. Let the user opt in

On Android 13+ request the `POST_NOTIFICATIONS` runtime permission, then:

```kotlin
lifecycleScope.launch { OliloNotifications.enable(context) }
// later...
lifecycleScope.launch { OliloNotifications.updatePreferences(context, prefs) }
lifecycleScope.launch { OliloNotifications.disable(context) }
```

`OliloMessagingService` re-registers automatically when FCM rotates the token.

---

## Payload reference

Notifications include a `data` block for deep-linking:

| Key | Values |
| --- | --- |
| `type` | `incident` \| `maintenance` \| `component` |
| `incidentId` | upstream id of the incident/component |
| `url` | status-page URL to open (when available) |

On both platforms the bundled handlers open `url` on tap; replace that with
in-app routing to the relevant incident when you're ready.
