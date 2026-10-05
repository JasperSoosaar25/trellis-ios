import SwiftUI
import GitHubKit

struct AppShell: View {
    @Environment(Session.self) private var session
    var body: some View {
        @Bindable var session = session
        TabView(selection: $session.tab) {
            Tab("Home", systemImage: "house", value: 0) { NavigationStack { HomeView() } }
            Tab("Repositories", systemImage: "shippingbox", value: 1) { NavigationStack { ResourceList(title: "Repositories", path: "/user/repos?sort=updated&per_page=50", kind: .repository, webPath: "/\(session.login)?tab=repositories").toolbar { NavigationLink { CreateRepositoryView() } label: { Image(systemName: "plus").accessibilityLabel("Create repository") } } } }
            Tab("Inbox", systemImage: "tray", value: 2) { NavigationStack { InboxView() } }.badge(session.unreadCount)
            Tab("Search", systemImage: "magnifyingglass", value: 3, role: .search) { NavigationStack { SearchView() } }
            Tab("More", systemImage: "square.grid.2x2", value: 4) { NavigationStack { MoreView() } }
        }.tabBarMinimizeBehavior(.onScrollDown).safeAreaInset(edge: .top, spacing: 0) { DemoBanner() }
            .onReceive(NotificationCenter.default.publisher(for: .trellisShortcut)) { note in if let tab = note.object as? Int { session.tab = tab; UserDefaults.standard.removeObject(forKey: "shortcutTab") } }
            .onAppear { if let tab = UserDefaults.standard.object(forKey: "shortcutTab") as? Int { session.tab = tab; UserDefaults.standard.removeObject(forKey: "shortcutTab") } }
    }
}

struct HomeView: View {
    @Environment(Session.self) private var session
    var body: some View {
        List {
            Section {
                NavigationLink { ProfileView() } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.profile["name"].string.isEmpty ? session.login : session.profile["name"].string).font(.title2.bold())
                        Text("@\(session.login)").foregroundStyle(.secondary)
                        Text(session.profile["bio"].string).font(.subheadline)
                    }.padding(.vertical, 6)
                }
                ContributionView()
            }
            Section("Your work") {
                NavigationLink { ResourceList(title: "Your issues", path: "/search/issues?" + URLCoding.query(["q": "is:issue is:open assignee:@me", "per_page": "50"]), key: "items", kind: .issue(""), webPath: "/issues") } label: { Label("Assigned issues", systemImage: "circle.dotted") }
                NavigationLink { ResourceList(title: "Pull requests", path: "/search/issues?" + URLCoding.query(["q": "is:pr is:open author:@me", "per_page": "50"]), key: "items", kind: .issue(""), webPath: "/pulls") } label: { Label("Your pull requests", systemImage: "arrow.triangle.pull") }
                NavigationLink { ResourceList(title: "Review requests", path: "/search/issues?" + URLCoding.query(["q": "is:pr is:open review-requested:@me", "per_page": "50"]), key: "items", kind: .issue(""), webPath: "/pulls") } label: { Label("Review requests", systemImage: "checkmark.bubble") }
            }
            Section("Explore") {
                Button("Discover repositories", systemImage: "sparkles") { session.browse("/explore") }
                Button("Trending", systemImage: "chart.line.uptrend.xyaxis") { session.browse("/trending") }
            }
        }.navigationTitle("Home")
    }
}

struct ProfileView: View {
    @Environment(Session.self) private var session
    var body: some View {
        List {
            Section { Text(session.profile["name"].string).font(.title.bold()); Text(session.profile["bio"].string); ContributionView() }
            Section { LabeledContent("Repositories", value: session.profile["public_repos"].string); LabeledContent("Followers", value: session.profile["followers"].string); LabeledContent("Following", value: session.profile["following"].string) }
            Button("Open profile on GitHub", systemImage: "safari") { session.browse("/\(session.login)") }
        }.navigationTitle(session.login)
    }
}

struct SearchView: View {
    @Environment(Session.self) private var session
    @State private var query = ""
    @State private var submitted = ""
    @State private var category = "repositories"
    var body: some View {
        VStack(spacing: 0) {
            Picker("Search for", selection: $category) { Text("Repositories").tag("repositories"); Text("Issues & PRs").tag("issues"); Text("Code").tag("code"); Text("People").tag("users") }.pickerStyle(.segmented).padding()
            if submitted.isEmpty { ContentUnavailableView("Find your next branch", systemImage: "magnifyingglass", description: Text("Search repositories, issues, pull requests, code, or people. GitHub search qualifiers are supported.")) }
            else { ResourceList(title: "Results", path: "/search/\(category)?" + URLCoding.query(["q": submitted, "per_page": "50"]), key: "items", kind: category == "repositories" ? .repository : category == "issues" ? .issue("") : .generic, webPath: "/search?" + URLCoding.query(["q": submitted, "type": category])) }
        }.navigationTitle("Search").searchable(text: $query, prompt: "Search GitHub").onSubmit(of: .search) { submitted = query.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
