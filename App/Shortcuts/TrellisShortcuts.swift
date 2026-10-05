import AppIntents
import Foundation

struct OpenInboxIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Trellis Inbox"
    static let description = IntentDescription("Open your notifications in Trellis.")
    static let openAppWhenRun = true
    func perform() async throws -> some IntentResult {
        await MainActor.run { UserDefaults.standard.set(2, forKey: "shortcutTab"); NotificationCenter.default.post(name: .trellisShortcut, object: 2) }
        return .result()
    }
}
struct OpenRepositoriesIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Trellis Repositories"
    static let openAppWhenRun = true
    func perform() async throws -> some IntentResult {
        await MainActor.run { UserDefaults.standard.set(1, forKey: "shortcutTab"); NotificationCenter.default.post(name: .trellisShortcut, object: 1) }
        return .result()
    }
}
struct TrellisShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenInboxIntent(), phrases: ["Open inbox in \(.applicationName)"], shortTitle: "Inbox", systemImageName: "tray")
        AppShortcut(intent: OpenRepositoriesIntent(), phrases: ["Open repositories in \(.applicationName)"], shortTitle: "Repositories", systemImageName: "shippingbox")
    }
}
extension Notification.Name { static let trellisShortcut = Notification.Name("TrellisShortcut") }
