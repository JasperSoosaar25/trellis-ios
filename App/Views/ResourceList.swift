import SwiftUI
import GitHubKit

enum ResourceKind: Hashable {
    case repository, issue(String), pull(String), workflow(String), run(String), job(String), file(String, String), organization, package(String, String), security(String, String), generic
}

struct ResourceList: View {
    let title: String
    let path: String
    var key = ""
    var kind: ResourceKind = .generic
    var webPath: String? = nil
    var editor: EditorDefinition? = nil
    @Environment(Session.self) private var session
    @State private var items: [ResourceItem] = []
    @State private var loading = true
    @State private var error: String?
    @State private var next: URL?
    @State private var offline = false
    @State private var query = ""
    @State private var presentedEditor: EditorDefinition?
    var body: some View {
        Group {
            if loading && items.isEmpty { ProgressView("Loading \(title.lowercased())…") }
            else if let error, items.isEmpty { FailureView(message: error) { Task { await load() } } }
            else {
                List {
                    if offline { Label("Offline · showing saved data", systemImage: "wifi.slash").foregroundStyle(.secondary) }
                    if let error { Text(error).foregroundStyle(.red) }
                    if items.isEmpty { ContentUnavailableView("No \(title.lowercased())", systemImage: "tray", description: Text("Items will appear here when available.")) }
                    ForEach(filtered) { item in
                        NavigationLink { ResourceDestination(value: item.value, kind: kind, webPath: webPath) } label: { ResourceRow(value: item.value) }
                    }
                    if next != nil { Button(loading ? "Loading…" : "Load more") { Task { await load(more: true) } }.disabled(loading) }
                }.refreshable { await load() }
            }
        }
        .navigationTitle(title)
        .searchable(text: $query, prompt: "Filter this list")
        .toolbar {
            if let editor { Button("Create", systemImage: "plus") { presentedEditor = editor } }
            if let webPath { Button("Open in browser", systemImage: "safari") { session.browse(webPath) } }
        }
        .sheet(item: $presentedEditor, onDismiss: { Task { await load() } }) { editor in EditorView(definition: editor) }
        .task(id: path) { await load() }
    }
    private var filtered: [ResourceItem] { query.isEmpty ? items : items.filter { ResourceRow(value: $0.value).title.localizedCaseInsensitiveContains(query) } }
    private func load(more: Bool = false) async {
        loading = true; error = nil
        defer { loading = false }
        do {
            let response = try await session.request(more ? next?.absoluteString ?? path : path)
            let value = key.isEmpty ? response.json : response.json.at(key)
            let array = value.array
            if !value.isNull && array.isEmpty && !value.object.isEmpty { items = [ResourceItem(value)] }
            else {
                let new = array.map { ResourceItem($0) }
                items = more ? items + new.filter { x in !items.contains { $0.id == x.id } } : new
            }
            next = response.nextURL; offline = response.isOffline
        } catch is CancellationError { } catch { self.error = error.localizedDescription }
    }
}

struct ResourceDestination: View {
    let value: JSON
    let kind: ResourceKind
    let webPath: String?
    @ViewBuilder var body: some View {
        switch kind {
        case .repository: RepositoryView(repository: value)
        case .issue(let repo): IssueDetailView(repo: repo.isEmpty ? repositoryName : repo, number: value["number"].int, pull: !value["pull_request"].isNull)
        case .pull(let repo): IssueDetailView(repo: repo, number: value["number"].int, pull: true)
        case .workflow(let repo): WorkflowView(repo: repo, workflow: value)
        case .run(let repo): RunView(repo: repo, run: value)
        case .job(let repo): LogView(repo: repo, job: value)
        case .file(let repo, let branch): FileView(repo: repo, branch: branch, item: value)
        case .organization: OrganizationView(organization: value)
        case .package(let root, let type): PackageView(root: root, type: type, package: value)
        case .security(let repo, let kind): SecurityAlertView(repo: repo, kind: kind, alert: value)
        case .generic: ResourceDetailView(value: value, webPath: webPath)
        }
    }
    private var repositoryName: String {
        let url = value["repository_url"].string
        return url.components(separatedBy: "/repos/").last ?? ""
    }
}

struct ResourceDetailView: View {
    let value: JSON
    var webPath: String? = nil
    @Environment(Session.self) private var session
    var body: some View {
        List {
            Section { ResourceRow(value: value) }
            if !value["body"].string.isEmpty { Section { MarkdownView(text: value["body"].string) } }
            ForEach(value.object.keys.sorted(), id: \.self) { key in
                let field = value[key]
                if !field.string.isEmpty && key != "body" {
                    LabeledContent(key.replacingOccurrences(of: "_", with: " ").capitalized) { Text(field.string).textSelection(.enabled) }
                } else if !field.object.isEmpty || !field.array.isEmpty {
                    NavigationLink(key.replacingOccurrences(of: "_", with: " ").capitalized) { JSONDetails(value: field) }
                }
            }
            if let route = resolvedWebPath { Button("Open on GitHub", systemImage: "safari") { session.browse(route) } }
        }.navigationTitle(ResourceRow(value: value).title).navigationBarTitleDisplayMode(.inline)
    }
    private var resolvedWebPath: String? { !value["html_url"].string.isEmpty ? value["html_url"].string : webPath }
}

struct JSONDetails: View {
    let value: JSON
    var body: some View {
        List {
            if !value.array.isEmpty { ForEach(Array(value.array.enumerated()), id: \.offset) { index, entry in NavigationLink("Item \(index + 1)") { ResourceDetailView(value: entry) } } }
            else { ForEach(value.object.keys.sorted(), id: \.self) { key in
                if value[key].object.isEmpty && value[key].array.isEmpty { LabeledContent(key.replacingOccurrences(of: "_", with: " "), value: value[key].string) }
                else { NavigationLink(key.replacingOccurrences(of: "_", with: " ")) { JSONDetails(value: value[key]) } }
            } }
        }.navigationTitle("Details")
    }
}
