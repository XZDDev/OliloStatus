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
//  2. The notifications backend URL is configured in `OliloNotificationConfig`
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

import Combine
import Foundation
import OSLog
import UIKit
import UserNotifications

// MARK: - Configuration

enum OliloNotificationConfig {
    /// Base URL of the notifications backend (no trailing slash).
    static let baseURL = URL(string: "https://notifications.olilo.co.uk")!
}

// MARK: - Preferences

/// Mirrors the backend's per-device preference shape.
struct NotificationPreferences: Codable, Equatable {
    var incidents: Bool = true
    var maintenance: Bool = true
    var componentAlerts: Bool = false
    /// Networks to receive status, incident, and maintenance alerts for. Empty = all networks.
    var networks: [String] = []

    static let storageKey = "notificationPreferences"

    /// Loads saved preferences from user defaults, falling back to defaults when absent or invalid.
    static func load() -> NotificationPreferences {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let prefs = try? JSONDecoder().decode(NotificationPreferences.self, from: data)
        else { return NotificationPreferences() }
        return prefs
    }

    /// Persists the current preference set in user defaults.
    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

// MARK: - API client

/// Thin async client over the backend's `/api/devices` endpoints.
struct NotificationsAPI {
    var baseURL = OliloNotificationConfig.baseURL

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

    /// Registers an APNs token with the backend using the current device preferences.
    func register(token: String, preferences: NotificationPreferences) async throws {
        let body = RegisterBody(
            token: token,
            preferences: preferences,
            locale: Locale.current.identifier,
            appVersion: Bundle.main.appVersion
        )
        try await send("POST", path: "api/devices/register", body: body)
    }

    /// Sends updated notification preferences for an already registered device token.
    func updatePreferences(token: String, preferences: NotificationPreferences) async throws {
        try await send(
            "PATCH",
            path: "api/devices/\(token)/preferences",
            body: PreferencesBody(preferences: preferences)
        )
    }

    /// Removes an APNs token from the backend delivery list.
    func unregister(token: String) async throws {
        try await send("DELETE", path: "api/devices/\(token)", body: PlatformBody())
    }

    /// Encodes and sends a JSON request, failing on non-success HTTP responses.
    private func send<Body: Encodable>(_ method: String, path: String, body: Body) async throws {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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

    /// Updates the in-memory and persisted opt-in flag together.
    private func setEnabled(_ value: Bool) {
        isEnabled = value
        UserDefaults.standard.set(value, forKey: Self.enabledKey)
    }
}

// MARK: - App delegate

/// Minimal `UIApplicationDelegate` that bridges APNs callbacks into
/// `PushManager`. Attach via `@UIApplicationDelegateAdaptor` (see file header).
final class PushAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// Installs this delegate as the notification center delegate during app launch.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Passes successful APNs token registration back to the push manager.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { await PushManager.shared.didReceive(deviceToken: deviceToken) }
    }

    /// Logs APNs registration failures without interrupting the app flow.
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Logger(subsystem: Bundle.main.bundleIdentifier ?? "uk.co.olilo.status", category: "PushNotifications")
            .error("APNs registration failed: \(error.localizedDescription, privacy: .public)")
    }

    /// Show banners while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    /// Handle a tapped notification by opening the in-app notices page.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            AppRouter.shared.openNotices()
            completionHandler()
        }
    }
}
