import Foundation
import UIKit
import UserNotifications
import Combine

class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    @Published var deviceToken: String?
    @Published var notificationPermissionGranted = false

    private let backendAPI = BackendAPI.shared
    private let userId = Config.deviceUserId

    override private init() {
        super.init()
    }

    // Request notification permissions
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])

            await MainActor.run {
                self.notificationPermissionGranted = granted
            }

            if granted {
                await registerForRemoteNotifications()
            }

            return granted
        } catch {
            print("❌ Failed to request notification permission: \(error)")
            return false
        }
    }

    // Register for remote notifications (must be called on main thread)
    @MainActor
    private func registerForRemoteNotifications() {
        #if !targetEnvironment(simulator)
        UIApplication.shared.registerForRemoteNotifications()
        #else
        print("📱 Push notifications not available on simulator")
        // For simulator, generate a fake token for testing
        let fakeToken = "simulator-\(UUID().uuidString.prefix(32))"
        self.handleDeviceToken(fakeToken)
        #endif
    }

    // Handle device token from AppDelegate
    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        handleDeviceToken(token)
    }

    // Handle device token string
    func handleDeviceToken(_ token: String) {
        print("📱 Device token received: \(token.prefix(20))...")
        self.deviceToken = token

        // Send token to backend
        Task {
            await sendTokenToBackend(token)
        }
    }

    // Send device token to backend
    private func sendTokenToBackend(_ token: String) async {
        do {
            try await backendAPI.updatePushToken(userId: userId, pushToken: token)
            print("✅ Push token sent to backend successfully")
        } catch {
            print("❌ Failed to send push token to backend: \(error)")
        }
    }

    // Handle notification received while app is in foreground
    func handleForegroundNotification(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        print("📬 Notification received in foreground: \(userInfo)")

        // Extract notification data
        if let title = userInfo["title"] as? String,
           let message = userInfo["message"] as? String {
            print("📬 \(title): \(message)")
        }
    }

    // Handle notification tap (when user taps on notification)
    func handleNotificationTap(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        print("👆 User tapped notification: \(userInfo)")

        // Navigate to relevant screen based on notification type
        if let alertType = userInfo["alert_type"] as? String {
            switch alertType {
            case "price":
                // Navigate to portfolio or specific stock
                if let symbol = userInfo["symbol"] as? String {
                    print("📈 Navigate to \(symbol)")
                }
            case "news":
                // Navigate to news or specific article
                if let url = userInfo["url"] as? String {
                    print("📰 Open news: \(url)")
                }
            case "social":
                // Navigate to social buzz for symbol
                if let symbol = userInfo["symbol"] as? String {
                    print("💬 Navigate to social buzz for \(symbol)")
                }
            default:
                print("📬 Unknown alert type: \(alertType)")
            }
        }
    }

    // Check current notification settings
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            self.notificationPermissionGranted = settings.authorizationStatus == .authorized
        }
        return settings.authorizationStatus
    }
}

// AppDelegate to handle push notification callbacks
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Called when APNs successfully registers the device
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        print("✅ APNs registration successful")
        PushNotificationManager.shared.handleDeviceToken(deviceToken)
    }

    // Called if APNs registration fails
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ APNs registration failed: \(error.localizedDescription)")
    }

    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        PushNotificationManager.shared.handleForegroundNotification(notification)
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        PushNotificationManager.shared.handleNotificationTap(response)
        completionHandler()
    }
}
