import SwiftUI
import UserNotifications
import GitHubKit

struct InboxView: View {
    @Environment(Session.self) private var session
    @Environment(\.scenePhase) private var phase
    @State private var notifications: [ResourceItem] = []
    @State private var all = false
    @State private var participating = false
    @State private var reason = "all"
    @State private var loading = false
    @State private var error: String?
    @State private var offline = false
    @State private var next: URL?
    @State private var nextPoll = Date.distantPast
    var body: some View {
        List {
            Section {
                Toggle("Include read notifications", isOn: $all)
                Toggle("Participating only", isOn: $participating)
                Picker("Reason", selection: $reason) { Text("All").tag("all"); Text("Mentions").tag("mention"); Text("Review requests").tag("review_requested"); Text("Assigned").tag("assign"); Text("Subscribed").tag("subscribed") }
            }
            if offline { Label("Offline · showing saved inbox", systemImage: "wifi.slash") }
            if let error { Text(error).foregroundStyle(.red); Button("Retry") { Task { await load() } } }
            if loading && notifications.isEmpty { ProgressView("Loading inbox…") }
            if !loading && notifications.isEmpty && error == nil { ContentUnavailableView("All caught up", systemImage: "tray", description: Text("New activity will appear here.")) }
            ForEach(notifications.filter { reason == "all" || $0.value["reason"].string == reason }) { item in
                NavigationLink { NotificationDestination(value: item.value) } label: { ResourceRow(value: item.value) }
                    .swipeActions(edge: .trailing) {
                        Button("Done", systemImage: "checkmark") { update(item, method: "DELETE") }.tint(.teal)
                        Button("Read", systemImage: "envelope.open") { update(item, method: "PATCH") }.tint(.blue)
                    }
                    .contextMenu {
                        Button("Subscribe") { subscribe(item, ignore: false) }
                        Button("Mute") { subscribe(item, ignore: true) }
                    }
            }
            if next != nil { Button("Load more") { Task { await load(more: true) } } }
        }.navigationTitle("Inbox").refreshable { await load() }
            .toolbar { ActionMenu(title: "Mark all read", actions: [APIAction(title: "Mark all notifications read", path: "/notifications", method: "PUT", body: .object(["last_read_at": .string(ISO8601DateFormatter().string(from: Date()))]))], onSuccess: { Task { await load(force: true) } }) }
            .task(id: "\(all)-\(participating)") { await load(force: true) }
            .task {
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(max(60, session.pollInterval))); if phase == .active && session.tab == 2 { await load() } }
                    catch { break }
                }
            }
    }
    private func load(more: Bool = false, force: Bool = false) async {
        guard !loading else { return }
        guard force || more || Date() >= nextPoll else { return }
        loading = true; defer { loading = false }
        do {
            let response = try await session.request(more ? next!.absoluteString : "/notifications?" + URLCoding.query(["all": String(all), "participating": String(participating), "per_page": "50"]))
            let page = response.json.array.map { ResourceItem($0) }; notifications = more ? notifications + page : page
            next = response.nextURL; offline = response.isOffline; error = nil
            session.unreadCount = notifications.filter { $0.value["unread"].bool }.count
            nextPoll = Date().addingTimeInterval(session.pollInterval)
        } catch { self.error = error.localizedDescription }
    }
    private func update(_ item: ResourceItem, method: String) {
        Task { do { _ = try await session.request("/notifications/threads/\(item.id)", method: method); notifications.removeAll { $0.id == item.id }; session.unreadCount = notifications.filter { $0.value["unread"].bool }.count } catch { self.error = error.localizedDescription } }
    }
    private func subscribe(_ item: ResourceItem, ignore: Bool) {
        Task { do { _ = try await session.request("/notifications/threads/\(item.id)/subscription", method: "PUT", body: .object(["ignored": .bool(ignore)])) } catch { self.error = error.localizedDescription } }
    }
}

struct NotificationDestination: View {
    let value: JSON
    @Environment(Session.self) private var session
    var body: some View {
        let repo = value.at("repository.full_name").string
        let type = value.at("subject.type").string
        let number = Int(value.at("subject.url").string.components(separatedBy: "/").last ?? "") ?? 0
        if ["Issue", "PullRequest"].contains(type) && number > 0 { IssueDetailView(repo: repo, number: number, pull: type == "PullRequest") }
        else { ResourceDetailView(value: value, webPath: "/\(repo)").toolbar { Button("Open on GitHub") { session.browse("/\(repo)") } } }
    }
}
