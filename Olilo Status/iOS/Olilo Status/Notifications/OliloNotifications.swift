//
//  OliloNotifications.swift
//  Olilo Status
//
//  Drop-in push-notification client for the Olilo Status notifications backend.
//
//  -- Setup (3 steps) -------------------------------------------------------
//  1. In Xcode: Target -> Signing & Capabilities -> + Capability ->
//     "Push Notifications". (Background Modes -> Remote notifications is optional
//     and only needed for silent/background pushes.)
//
//  2. Set your backend URL (and optional API key) in `OliloNotificationConfig`
//     below.
//
//  3. Wire the app delegate into the SwiftUI entry point. In `Olilo.swift`:
//
//         @main
//         struct Olilo_StatusApp: App {
//             @UIApplicationDelegateAdaptor(PushAppDelegate.self) var appDelegate
//             var body: some Scene {
//                 WindowGroup { ContentView() }
//             }
//         }
//
//  That's it. Call `PushManager.shared.enableNotifications()` when the user
//  opts in (e.g. from the bundled `NotificationSettingsView`), and the device
//  registers itself with the backend automatically.
//

import Foundation
import UIKit
import UserNotifications

// MARK: - Configuration

enum OliloNotificationConfig {
    /// Base URL of the notifications backend (no trailing slash).
    static let baseURL = URL(string: "https://notifications.example.com")!

    /// Shared secret sent as `x-api-key`. Leave `nil` if the backend has no
    /// API_KEY configured. Note: a key shipped in the app is not a strong
    /// secret - it only deters casual abuse of the registration endpoint.
    static let apiKey: String? = nil
}

// MARK: - Preferences

/// Mirrors the backend's per-device preference shape.
struct NotificationPreferences: Codable, Equatable {
    var incidents: Bool = true
    var maintenance: Bool = true
    var componentAlerts: Bool = false
    /// Networks to receive component-level alerts for. Empty = all networks.
    var networks: [String] = []

    static let storageKey = "notificationPreferences"

    static func load() -> NotificationPreferences {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let prefs = try? JSONDecoder().decode(NotificationPreferences.self, from: data)
        else { return NotificationPreferences() }
        return prefs
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

// MARK: - API client

/// Thin async client over the backend's `/api/devices` endpoints.
struct NotificationsAPI {
    var baseURL = OliloNotificationConfig.baseURL
    var apiKey = OliloNotificationConfig.apiKey

    private struct RegisterBody: Encodable {
        let token: String
        let platform = "ios"
        let preferences: NotificationPreferences
        let locale: String
        let appVersion: String
    }

    private struct PreferencesBody: Encodable {
        let platform = "ios"
        let preferences: NotificationPreferences
    }

    private struct PlatformBody: Encodable {
        let platform = "ios"
    }

    func register(token: String, preferences: NotificationPreferences) async throws {
        let body = RegisterBody(
            token: token,
            preferences: preferences,
            locale: Locale.current.identifier,
            appVersion: Bundle.main.appVersion
        )
        try await send("POST", path: "api/devices/register", body: body)
    }

    func updatePreferences(token: String, preferences: NotificationPreferences) async throws {
        try await send(
            "PATCH",
            path: "api/devices/\(token)/preferences",
            body: PreferencesBody(preferences: preferences)
        )
    }

    func unregister(token: String) async throws {
        try await send("DELETE", path: "api/devices/\(token)", body: PlatformBody())
    }

    private func send<Body: Encodable>(_ method: String, path: String, body: Body) async throws {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey { request.setValue(apiKey, forHTTPHeaderField: "x-api-key") }
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

private extension Bundle {
    var appVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
    }
}

// MARK: - Push manager

/// Owns the device token and preference state, and keeps the backend in sync.
/// Use the shared instance from SwiftUI views and the app delegate.
@MainActor
final class PushManager: ObservableObject {
    static let shared = PushManager()

    /// Whether the user has opted into notifications in-app.
    @Published private(set) var isEnabled: Bool = UserDefaults.standard.bool(forKey: enabledKey)
    @Published var preferences = NotificationPreferences.load()

    private static let enabledKey = "notificationsEnabled"
    private static let tokenKey = "apnsDeviceToken"

    private let api = NotificationsAPI()
    private var deviceToken: String? {
        get { UserDefaults.standard.string(forKey: Self.tokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.tokenKey) }
    }

    private init() {}

    /// Request system permission and, if granted, register for remote
    /// notifications. The token arrives asynchronously in the app delegate.
    func enableNotifications() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        guard granted else {
            setEnabled(false)
            return
        }
        setEnabled(true)
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Turn notifications off and tell the backend to stop delivering.
    func disableNotifications() async {
        setEnabled(false)
        if let token = deviceToken {
            try? await api.unregister(token: token)
        }
    }

    /// Persist new preferences and push them to the backend if registered.
    func updatePreferences(_ prefs: NotificationPreferences) async {
        preferences = prefs
        prefs.save()
        guard isEnabled, let token = deviceToken else { return }
        try? await api.updatePreferences(token: token, preferences: prefs)
    }

    // MARK: Called by the app delegate

    /// APNs delivered a device token - register it with the backend.
    func didReceive(deviceToken data: Data) async {
        let token = data.map { String(format: "%02x", $0) }.joined()
        deviceToken = token
        guard isEnabled else { return }
        try? await api.register(token: token, preferences: preferences)
    }

    private func setEnabled(_ value: Bool) {
        isEnabled = value
        UserDefaults.standard.set(value, forKey: Self.enabledKey)
    }
}

// MARK: - App delegate

/// Minimal `UIApplicationDelegate` that bridges APNs callbacks into
/// `PushManager`. Attach via `@UIApplicationDelegateAdaptor` (see file header).
final class PushAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { await PushManager.shared.didReceive(deviceToken: deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs registration failed: \(error.localizedDescription)")
    }

    /// Show banners while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    /// Handle a tapped notification. The backend payload carries
    /// `{ type, incidentId, url }` in `userInfo` for deep-linking.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        if let urlString = info["url"] as? String, let url = URL(string: urlString) {
            // Hook for deep-linking; for now open the status page in-app/Safari.
            Task { @MainActor in UIApplication.shared.open(url) }
        }
        completionHandler()
    }
}
