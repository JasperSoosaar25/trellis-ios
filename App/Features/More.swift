import SwiftUI
import UserNotifications
import GitHubKit

struct MoreView: View {
    @Environment(Session.self) private var session
    var body: some View {
        List {
            Section("Workspace") {
                NavigationLink { ProjectsView(owner: session.login) } label: { Label("Projects", systemImage: "rectangle.3.group") }
                NavigationLink { AdminResourceView(spec: .gists) } label: { Label("Gists", systemImage: "doc.text") }
                NavigationLink { CodespacesView() } label: { Label("Codespaces", systemImage: "desktopcomputer") }
                NavigationLink { ResourceList(title: "Organizations", path: "/user/orgs?per_page=100", kind: .organization, webPath: "/settings/organizations") } label: { Label("Organizations & teams", systemImage: "person.3") }
                NavigationLink { PackagesView(owner: session.login, organization: false) } label: { Label("Packages", systemImage: "cube.box") }
            }
            Section("Account") {
                NavigationLink { AdminResourceView(spec: .sshKeys) } label: { Label("SSH keys", systemImage: "key") }
                NavigationLink { AdminResourceView(spec: .gpgKeys) } label: { Label("GPG keys", systemImage: "signature") }
                NavigationLink { AdminResourceView(spec: .sshSigningKeys) } label: { Label("SSH signing keys", systemImage: "checkmark.seal") }
                Button("Personal access tokens", systemImage: "lock.shield") { session.browse("/settings/tokens") }
                Button("Sponsors", systemImage: "heart") { session.browse("/sponsors") }
                Button("Copilot chat & agent sessions", systemImage: "bubble.left.and.bubble.right") { session.browse("/copilot") }
                Button("Marketplace", systemImage: "storefront") { session.browse("/marketplace") }
                Button("Billing & usage", systemImage: "chart.bar") { session.browse("/settings/billing") }
                Button("All account settings", systemImage: "person.crop.circle") { session.browse("/settings/profile") }
            }
            Section { NavigationLink { SettingsView() } label: { Label("Trellis settings", systemImage: "gearshape") } }
        }.navigationTitle("More")
    }
}

struct SettingsView: View {
    @Environment(Session.self) private var session
    @AppStorage("pollingEnabled") private var polling = false
    @State private var notificationError: String?
    @State private var logout = false
    var body: some View {
        Form {
            Section("Account") { LabeledContent("Signed in as", value: session.login)
                if let missing = AuthScopes.missing(requested: session.requestedScopes, granted: session.grantedScopes) {
                    if missing.isEmpty { Label("Requested permissions granted", systemImage: "checkmark.circle") }
                    else { Text("Missing scopes: " + missing.joined(separator: ", ")).font(.footnote).foregroundStyle(.orange) }
                } else { Text("Scopes are unknown for this token. Fine-grained tokens use repository permissions instead.").font(.footnote).foregroundStyle(.secondary) }
                Text("Repository roles, organization approval and SSO authorization still apply.").font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Background inbox notifications", isOn: $polling)
                if let notificationError { Text(notificationError).foregroundStyle(.red) }
            } header: { Text("Notifications") } footer: { Text("iOS chooses when background refresh runs. This polls the API and sends local notifications; delivery may be delayed. Notification previews contain only a count.") }
            Section("Privacy & storage") {
                Button("Clear API cache") { Task { await session.client?.clearCache() } }
                Text("Tokens stay in the device's default Keychain group. No analytics or advertising.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("About") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                Text("Unofficial. Not affiliated with or endorsed by GitHub.")
                Text("System appearance follows Liquid Glass, Dark Mode, text size and accessibility settings.").font(.footnote).foregroundStyle(.secondary)
                Button("Source & feature coverage", systemImage: "safari") { session.browse("https://github.com/JasperSoosaar25/trellis-ios") }
            }
            Button("Sign out", role: .destructive) { logout = true }
        }.navigationTitle("Settings")
            .onChange(of: polling) { _, value in
                if value { Task { do { let accepted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]); if accepted { notificationError = nil; BackgroundRefresh.schedule() } else { polling = false; notificationError = "Notifications are disabled. Enable them in iOS Settings." } } catch { polling = false; notificationError = error.localizedDescription } } }
                else { BackgroundRefresh.cancel() }
            }
            .confirmationDialog("Sign out of Trellis?", isPresented: $logout, titleVisibility: .visible) { Button("Sign out", role: .destructive) { Task { await session.logout() } } } message: { Text("Your saved API token and cached API data will be removed. Browser login is separate.") }
    }
}

struct RepositoryExtras: View {
    let repo: String
    @Environment(Session.self) private var session
    var body: some View {
        List {
            NavigationLink { AdminResourceView(spec: .releases(repo)) } label: { Label("Releases", systemImage: "tag") }
            NavigationLink { DiscussionsView(repo: repo) } label: { Label("Discussions", systemImage: "bubble.left.and.bubble.right") }
            NavigationLink { ProjectsView(owner: String(repo.split(separator: "/").first ?? "")) } label: { Label("Owner's projects", systemImage: "rectangle.3.group") }
            NavigationLink { SecurityView(repo: repo) } label: { Label("Security", systemImage: "lock.shield") }
            NavigationLink { InsightsView(repo: repo) } label: { Label("Insights", systemImage: "chart.xyaxis.line") }
            Button("Wiki", systemImage: "book") { session.browse("/\(repo)/wiki") }
            Button("Repository projects", systemImage: "safari") { session.browse("/\(repo)/projects") }
        }.navigationTitle("More in this repository")
    }
}

struct OrganizationView: View {
    let organization: JSON
    @Environment(Session.self) private var session
    var org: String { organization["login"].string }
    var body: some View {
        List {
            ResourceRow(value: organization)
            NavigationLink { ResourceList(title: "Repositories", path: "/orgs/\(org)/repos?per_page=100", kind: .repository, webPath: "/orgs/\(org)/repositories") } label: { Text("Repositories") }
            NavigationLink { AdminResourceView(spec: .teams(org)) } label: { Text("Teams") }
            NavigationLink { ResourceList(title: "Members", path: "/orgs/\(org)/members?per_page=100", webPath: "/orgs/\(org)/people") } label: { Text("Members") }
            NavigationLink { ProjectsView(owner: org, organization: true) } label: { Text("Projects") }
            NavigationLink { PackagesView(owner: org, organization: true) } label: { Text("Packages") }
            NavigationLink { ActionsAdministration(root: "/orgs/\(org)/actions", webPath: "/organizations/\(org)/settings/actions") } label: { Text("Organization Actions settings") }
            NavigationLink { ResourceList(title: "Copilot seats", path: "/orgs/\(org)/copilot/billing/seats?per_page=100", key: "seats", webPath: "/organizations/\(org)/settings/copilot") } label: { Text("Copilot administration") }
            Button("All organization settings") { session.browse("/organizations/\(org)/settings/profile") }
        }.navigationTitle(org)
    }
}

struct CodespacesView: View {
    @Environment(Session.self) private var session
    @State private var spaces: [ResourceItem] = []
    @State private var error: String?
    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.red); Button("Retry") { Task { await load() } } }
            if spaces.isEmpty && error == nil { ContentUnavailableView("No Codespaces", systemImage: "desktopcomputer") }
            ForEach(spaces) { space in
                VStack(alignment: .leading) {
                    ResourceRow(value: space.value)
                    ActionMenu(title: "Manage Codespace", actions: [APIAction(title: "Start \(space.value["name"].string) (uses quota)", path: "/user/codespaces/\(URLCoding.segment(space.value["name"].string))/start"), APIAction(title: "Stop \(space.value["name"].string)", path: "/user/codespaces/\(URLCoding.segment(space.value["name"].string))/stop"), APIAction(title: "Delete \(space.value["name"].string)", path: "/user/codespaces/\(URLCoding.segment(space.value["name"].string))", method: "DELETE", destructive: true)], onSuccess: { Task { await load() } })
                }
            }
            Button("Open Codespaces in browser") { session.browse("/codespaces") }
        }.navigationTitle("Codespaces").task { await load() }.refreshable { await load() }
    }
    private func load() async { do { spaces = try await session.request("/user/codespaces?per_page=100").json["codespaces"].array.map { ResourceItem($0) }; error = nil } catch { self.error = error.localizedDescription } }
}

struct PackagesView: View {
    let owner: String
    let organization: Bool
    @State private var type = "container"
    var root: String { organization ? "/orgs/\(owner)" : "/users/\(owner)" }
    var body: some View {
        VStack {
            Picker("Package registry", selection: $type) { ForEach(["container", "npm", "maven", "rubygems", "nuget", "docker"], id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu)
            ResourceList(title: "Packages", path: root + "/packages?package_type=\(type)&per_page=100", kind: .package(root, type), webPath: organization ? "/orgs/\(owner)/packages" : "/\(owner)?tab=packages")
        }
    }
}

struct PackageView: View {
    let root: String
    let type: String
    let package: JSON
    @Environment(Session.self) private var session
    var path: String { root + "/packages/\(type)/\(URLCoding.segment(package["name"].string))" }
    var body: some View {
        List {
            ResourceRow(value: package)
            NavigationLink { AdminResourceView(spec: AdminSpec(title: "Versions", root: path + "/versions", web: package["html_url"].string, createMethod: nil, editMethod: nil)) } label: { Text("Versions") }
            ActionMenu(title: "Package actions", actions: [APIAction(title: "Delete package \(package["name"].string)", path: path, method: "DELETE", destructive: true), APIAction(title: "Restore package", path: path + "/restore")])
            Button("Open package page") { session.browse(package["html_url"].string.isEmpty ? "/" : package["html_url"].string) }
        }.navigationTitle(package["name"].string)
    }
}

struct SecurityView: View {
    let repo: String
    var body: some View {
        List {
            ForEach(["dependabot", "code-scanning", "secret-scanning"], id: \.self) { kind in
                NavigationLink { ResourceList(title: kind.replacingOccurrences(of: "-", with: " ").capitalized, path: "/repos/\(repo)/\(kind)/alerts?per_page=100", kind: .security(repo, kind), webPath: "/\(repo)/security") } label: { Text(kind.replacingOccurrences(of: "-", with: " ").capitalized) }
            }
            NavigationLink { ResourceList(title: "Security advisories", path: "/repos/\(repo)/security-advisories?per_page=100", webPath: "/\(repo)/security/advisories") } label: { Text("Repository advisories") }
        }.navigationTitle("Security")
    }
}

struct SecurityAlertView: View {
    let repo: String
    let kind: String
    let alert: JSON
    @State private var editor: EditorDefinition?
    var body: some View {
        ResourceDetailView(value: alert, webPath: "/\(repo)/security")
            .toolbar { Button("Update alert") {
                let secret = kind == "secret-scanning"
                editor = EditorDefinition(title: "Update alert", path: "/repos/\(repo)/\(kind)/alerts/\(alert["number"].string)", method: "PATCH", fields: [FieldDefinition(key: "state", label: "State", type: .choice(secret ? ["resolved", "open"] : ["dismissed", "open"])), FieldDefinition(key: secret ? "resolution" : "dismissed_reason", label: "Reason", type: .choice(secret ? ["false_positive", "revoked", "used_in_tests", "wont_fix"] : kind == "dependabot" ? ["fix_started", "inaccurate", "no_bandwidth", "not_used", "tolerable_risk"] : ["false positive", "won't fix", "used in tests"])), FieldDefinition(key: secret ? "resolution_comment" : "dismissed_comment", label: "Comment", type: .multiline)])
            } }.sheet(item: $editor) { EditorView(definition: $0) }
    }
}

struct InsightsView: View {
    let repo: String
    @Environment(Session.self) private var session
    var body: some View {
        List {
            NavigationLink { ResourceList(title: "Traffic views", path: "/repos/\(repo)/traffic/views", webPath: "/\(repo)/graphs/traffic") } label: { Text("Traffic views") }
            NavigationLink { ResourceList(title: "Clones", path: "/repos/\(repo)/traffic/clones", webPath: "/\(repo)/graphs/traffic") } label: { Text("Clones") }
            NavigationLink { ResourceList(title: "Referrers", path: "/repos/\(repo)/traffic/popular/referrers", webPath: "/\(repo)/graphs/traffic") } label: { Text("Popular referrers") }
            NavigationLink { ResourceList(title: "Contributors", path: "/repos/\(repo)/stats/contributors", webPath: "/\(repo)/graphs/contributors") } label: { Text("Contributors") }
            Button("Pulse and complete graphs") { session.browse("/\(repo)/pulse") }
        }.navigationTitle("Insights")
    }
}

extension AdminSpec {
    static var gists: AdminSpec { AdminSpec(title: "Gists", root: "/gists", web: "https://gist.github.com", fields: [FieldDefinition(key: "description", label: "Description"), FieldDefinition(key: "public", label: "Public", type: .toggle), FieldDefinition(key: "files", label: "Files", type: .json, required: true, help: "Object keyed by filename, each with a content string. Existing files can be updated or set to null to delete.")], help: "A secret gist is accessible to anyone with its link.") }
    static var sshKeys: AdminSpec { AdminSpec(title: "SSH keys", root: "/user/keys", web: "/settings/keys", fields: [FieldDefinition(key: "title", label: "Title", required: true), FieldDefinition(key: "key", label: "Public SSH key", type: .multiline, required: true)], editMethod: nil) }
    static var gpgKeys: AdminSpec { AdminSpec(title: "GPG keys", root: "/user/gpg_keys", web: "/settings/keys", fields: [FieldDefinition(key: "armored_public_key", label: "Armored public key", type: .multiline, required: true)], editMethod: nil) }
    static var sshSigningKeys: AdminSpec { AdminSpec(title: "SSH signing keys", root: "/user/ssh_signing_keys", web: "/settings/keys", fields: [FieldDefinition(key: "title", label: "Title", required: true), FieldDefinition(key: "key", label: "Public SSH signing key", type: .multiline, required: true)], editMethod: nil) }
    static func teams(_ org: String) -> AdminSpec { AdminSpec(title: "Teams", root: "/orgs/\(org)/teams", identity: "slug", web: "/orgs/\(org)/teams", fields: [FieldDefinition(key: "name", label: "Name", required: true), FieldDefinition(key: "description", label: "Description"), FieldDefinition(key: "privacy", label: "Privacy", type: .choice(["closed", "secret"])), FieldDefinition(key: "maintainers", label: "Maintainers", type: .csv)]) }
}
