import UserNotifications
import PluginHubCore

public struct NotificationManager: Sendable {
    public init() {}

    public func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                print("通知权限已授权")
            }
        }
    }

    public func send(notification: PluginNotification) {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body

        if notification.sound == true {
            content.sound = .default
        }

        var trigger: UNNotificationTrigger?
        if let scheduledAt = notification.scheduledAt, scheduledAt > Date() {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: scheduledAt)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("通知发送失败: \(error.localizedDescription)")
            }
        }
    }
}
