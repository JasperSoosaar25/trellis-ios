import Foundation
import UIKit
@preconcurrency import BackgroundTasks
import UserNotifications
import GitHubKit

@MainActor final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: BackgroundRefresh.identifier, using: .main) { task in
            guard let refresh = task as? BGAppRefreshTask else { task.setTaskCompleted(success: false); return }
            let operation = Task { @MainActor in await BackgroundRefresh.perform(refresh) }
            refresh.expirationHandler = { operation.cancel() }
        }
        return true
    }
}

@MainActor enum BackgroundRefresh {
    static let identifier = "dev.trellis.client.refresh"
    static func schedule() {
        guard UserDefaults.standard.bool(forKey: "pollingEnabled"), Keychain.read() != nil else { return }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        let interval = max(900, UserDefaults.standard.double(forKey: "pollInterval"))
        request.earliestBeginDate = Date().addingTimeInterval(interval)
        try? BGTaskScheduler.shared.submit(request)
    }
    static func cancel() { BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier) }
    static func perform(_ task: BGAppRefreshTask) async {
        defer { schedule() }
        guard UserDefaults.standard.bool(forKey: "pollingEnabled"), let token = Keychain.read() else { task.setTaskCompleted(success: true); return }
        let next = UserDefaults.standard.double(forKey: "nextNotificationPoll")
        guard Date().timeIntervalSince1970 >= next else { task.setTaskCompleted(success: true); return }
        do {
            let client = GitHubClient(token: token)
            let response = try await client.request("/notifications?per_page=50", useCache: false)
            try Task.checkCancellation()
            let ids = response.json.array.map { $0["id"].string }
            let baseline = UserDefaults.standard.stringArray(forKey: "seenNotifications")
            let prior = Set(baseline ?? [])
            let newCount = ids.filter { !prior.contains($0) }.count
            let interval = await client.pollInterval
            UserDefaults.standard.set(interval, forKey: "pollInterval")
            UserDefaults.standard.set(Date().addingTimeInterval(interval).timeIntervalSince1970, forKey: "nextNotificationPoll")
            // The first snapshot establishes a baseline, avoiding a flood on opt-in.
            if baseline != nil && newCount > 0 {
                let content = UNMutableNotificationContent()
                content.title = "New activity"
                content.body = "You have \(newCount) new notification\(newCount == 1 ? "" : "s") in Trellis."
                content.sound = .default
                try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "trellis-inbox", content: content, trigger: nil))
            }
            let recent = ids + (baseline ?? []).filter { !ids.contains($0) }
            UserDefaults.standard.set(Array(recent.prefix(500)), forKey: "seenNotifications")
            task.setTaskCompleted(success: true)
        } catch { task.setTaskCompleted(success: false) }
    }
}
