import Foundation
import UserNotifications

enum NotificationService {
    static func postOfflineAlert(for service: Service) async {
        let content = UNMutableNotificationContent()
        content.title = "\(service.name) is offline"
        content.body = "\(service.displayURL) is not responding."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "offline-\(service.id.uuidString)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
