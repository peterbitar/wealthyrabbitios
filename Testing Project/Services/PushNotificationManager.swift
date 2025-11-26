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
                await MainActor.run {
                    registerForRemoteNotifications()
                }
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
        let content = notification.request.content
        print("📬 Notification received in foreground: \(userInfo)")
        
        // Extract notification text from various possible formats
        var notificationText: String? = nil
        
        // Try custom format: title + message
        if let title = userInfo["title"] as? String,
           let message = userInfo["message"] as? String {
            notificationText = message.isEmpty ? title : "\(title): \(message)"
            print("📬 Extracted from title/message: \(notificationText ?? "")")
        }
        // Try custom format: body
        else if let body = userInfo["body"] as? String {
            notificationText = body
            print("📬 Extracted from body: \(notificationText ?? "")")
        }
        // Try standard APNs format: aps.alert
        else if let aps = userInfo["aps"] as? [String: Any] {
            if let alert = aps["alert"] as? [String: Any] {
                if let title = alert["title"] as? String,
                   let body = alert["body"] as? String {
                    notificationText = "\(title): \(body)"
                    print("📬 Extracted from aps.alert: \(notificationText ?? "")")
                } else if let body = alert["body"] as? String {
                    notificationText = body
                    print("📬 Extracted from aps.alert.body: \(notificationText ?? "")")
                }
            } else if let alert = aps["alert"] as? String {
                notificationText = alert
                print("📬 Extracted from aps.alert (string): \(notificationText ?? "")")
            }
        }
        // Try direct content body (for local notifications)
        else if !content.body.isEmpty {
            notificationText = content.body
            print("📬 Extracted from content.body: \(notificationText ?? "")")
        }
        // Fallback: try to extract any text from userInfo
        else if let text = userInfo["text"] as? String {
            notificationText = text
            print("📬 Extracted from text: \(notificationText ?? "")")
        }
        
        // Mirror notification to Rabbit chat if we found text
        if let text = notificationText {
            appendNotificationToRabbitChat(text)
        } else {
            print("⚠️ Could not extract notification text from payload: \(userInfo)")
        }
    }
    
    // Helper to append notification to Rabbit chat
    // This ensures notifications appear in the conversation
    func appendNotificationToRabbitChat(_ notificationText: String) {
        print("📨 Posting notification to Rabbit chat: \(notificationText.prefix(50))...")
        // Post notification to NotificationCenter so RabbitViewModel can pick it up
        // Use main queue to ensure UI updates happen on main thread
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("RabbitNotificationReceived"),
                object: nil,
                userInfo: ["message": notificationText]
            )
        }
    }

    // Handle notification tap (when user taps on notification)
    func handleNotificationTap(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        let content = response.notification.request.content
        print("👆 User tapped notification: \(userInfo)")

        // Extract notification text from various possible formats
        var notificationText: String? = nil
        
        // Try custom format: title + message
        if let title = userInfo["title"] as? String,
           let message = userInfo["message"] as? String {
            notificationText = message.isEmpty ? title : "\(title): \(message)"
        }
        // Try custom format: body
        else if let body = userInfo["body"] as? String {
            notificationText = body
        }
        // Try standard APNs format: aps.alert
        else if let aps = userInfo["aps"] as? [String: Any] {
            if let alert = aps["alert"] as? [String: Any] {
                if let title = alert["title"] as? String,
                   let body = alert["body"] as? String {
                    notificationText = "\(title): \(body)"
                } else if let body = alert["body"] as? String {
                    notificationText = body
                }
            } else if let alert = aps["alert"] as? String {
                notificationText = alert
            }
        }
        // Try direct content body
        else if !content.body.isEmpty {
            notificationText = content.body
        }
        // Fallback: try to extract any text from userInfo
        else if let text = userInfo["text"] as? String {
            notificationText = text
        }
        
        // Mirror notification to Rabbit chat if we found text
        if let text = notificationText {
            appendNotificationToRabbitChat(text)
        } else {
            print("⚠️ Could not extract notification text from tapped notification: \(userInfo)")
        }

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
        
        // Check if app was launched from a notification
        if let notification = launchOptions?[.remoteNotification] as? [String: Any] {
            print("📱 App launched from remote notification: \(notification)")
            // Process notification after a short delay to ensure app is fully initialized
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.processNotificationPayload(notification)
            }
        }
        
        return true
    }
    
    // Helper to process notification payload
    private func processNotificationPayload(_ userInfo: [String: Any]) {
        var notificationText: String? = nil
        
        // Try custom format: title + message
        if let title = userInfo["title"] as? String,
           let message = userInfo["message"] as? String {
            notificationText = message.isEmpty ? title : "\(title): \(message)"
        }
        // Try custom format: body
        else if let body = userInfo["body"] as? String {
            notificationText = body
        }
        // Try standard APNs format: aps.alert
        else if let aps = userInfo["aps"] as? [String: Any] {
            if let alert = aps["alert"] as? [String: Any] {
                if let title = alert["title"] as? String,
                   let body = alert["body"] as? String {
                    notificationText = "\(title): \(body)"
                } else if let body = alert["body"] as? String {
                    notificationText = body
                }
            } else if let alert = aps["alert"] as? String {
                notificationText = alert
            }
        }
        
        if let text = notificationText {
            PushNotificationManager.shared.appendNotificationToRabbitChat(text)
        }
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
