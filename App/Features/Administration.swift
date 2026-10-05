import SwiftUI
import GitHubKit

struct AdminSpec {
    let title: String
    let root: String
    var key = ""
    var identity = "id"
    let web: String
    var fields: [FieldDefinition] = []
    var createMethod: String? = "POST"
    var editMethod: String? = "PATCH"
    var canDelete = true
    var createSuffix = ""
    var itemSuffix = "/{id}"
    var help = ""
}

struct AdminResourceView: View {
    let spec: AdminSpec
    @Environment(Session.self) private var session
    @State private var items: [ResourceItem] = []
    @State private var loading = true
    @State private var error: String?
    @State private var editor: EditorDefinition?
    @State private var next: URL?
    var body: some View {
        List {
            if loading && items.isEmpty { ProgressView("Loading…") }
            if let error { Text(error).foregroundStyle(.red); Button("Retry") { Task { await load() } } }
            if !loading && items.isEmpty && error == nil { ContentUnavailableView("No \(spec.title.lowercased())", systemImage: "tray") }
            ForEach(items) { item in
                NavigationLink {
                    List {
                        ResourceDetailView(value: item.value, webPath: spec.web)
                        if let method = spec.editMethod, !spec.fields.isEmpty { Button("Edit") { editor = definition(method: method, item: item.value) } }
                        if spec.canDelete { ActionMenu(title: "Delete", actions: [APIAction(title: "Delete \(ResourceRow(value: item.value).title)", path: itemPath(item.value), method: "DELETE", destructive: true)], onSuccess: { Task { await load() } }) }
                        if spec.title == "Environments" {
                            NavigationLink { SecretList(root: itemPath(item.value) + "/secrets", webPath: spec.web) } label: { Text("Environment secrets") }
                            NavigationLink { AdminResourceView(spec: .environmentVariables(itemPath(item.value), web: spec.web)) } label: { Text("Environment variables") }
                        }
                    }.navigationTitle(ResourceRow(value: item.value).title).navigationBarTitleDisplayMode(.inline)
                } label: { ResourceRow(value: item.value) }
            }
            if next != nil { Button("Load more") { Task { await load(more: true) } } }
            Button("Open settings on GitHub", systemImage: "safari") { session.browse(spec.web) }
        }.navigationTitle(spec.title)
            .toolbar { if let method = spec.createMethod, !spec.fields.isEmpty { Button("Create", systemImage: "plus") { editor = definition(method: method) } } }
            .sheet(item: $editor, onDismiss: { Task { await load() } }) { EditorView(definition: $0) }
            .task { await load() }.refreshable { await load() }
    }
    private func itemPath(_ item: JSON) -> String { spec.root + spec.itemSuffix.replacingOccurrences(of: "{id}", with: URLCoding.segment(item[spec.identity].string)) }
    private func definition(method: String, item: JSON = .null) -> EditorDefinition {
        let values = item.object.filter { key, _ in spec.fields.contains { $0.key == key } }
        let path = item.isNull ? spec.root + spec.createSuffix : itemPath(item)
        return EditorDefinition(title: (item.isNull ? "Create " : "Edit ") + spec.title.lowercased(), path: path, method: method, fields: spec.fields, initial: .object(values), help: spec.help)
    }
    private func load(more: Bool = false) async {
        loading = true; defer { loading = false }
        do {
            let path = more ? next!.absoluteString : spec.root + (spec.root.contains("?") ? "&" : "?") + "per_page=100"
            let response = try await session.request(path); let value = spec.key.isEmpty ? response.json : response.json.at(spec.key)
            let page = value.array.map { ResourceItem($0) }; items = more ? items + page : page; next = response.nextURL; error = nil
        } catch { self.error = error.localizedDescription }
    }
}

struct SettingsResourceView: View {
    let title: String
    let path: String
    let webPath: String
    let fields: [FieldDefinition]
    var method = "PUT"
    @Environment(Session.self) private var session
    @State private var value: JSON = .null
    @State private var error: String?
    @State private var editor: EditorDefinition?
    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.red); Button("Retry") { Task { await load() } } }
            if !value.isNull { ForEach(fields) { field in LabeledContent(field.label, value: value[field.key].string.isEmpty ? "Configured" : value[field.key].string) }; Button("Edit settings") {
                var initial = value.object.filter { key, _ in fields.contains { $0.key == key } }
                if !value.at("enforce_admins.enabled").isNull { initial["enforce_admins"] = value.at("enforce_admins.enabled") }
                editor = EditorDefinition(title: title, path: path, method: method, fields: fields, initial: .object(initial))
            } } else if error == nil { ProgressView() }
            Button("Open advanced settings", systemImage: "safari") { session.browse(webPath) }
        }.navigationTitle(title).task { await load() }.sheet(item: $editor, onDismiss: { Task { await load() } }) { EditorView(definition: $0) }
    }
    private func load() async { do { value = try await session.request(path).json; error = nil } catch { self.error = error.localizedDescription } }
}

extension AdminSpec {
    static func variables(_ root: String, web: String) -> AdminSpec {
        var fields = [FieldDefinition(key: "name", label: "Name", required: true), FieldDefinition(key: "value", label: "Value", type: .multiline, required: true)]
        if root.hasPrefix("/orgs/") { fields += [FieldDefinition(key: "visibility", label: "Visibility", type: .choice(["private", "all", "selected"])), FieldDefinition(key: "selected_repository_ids", label: "Selected repository IDs", type: .json, help: "Array of numeric IDs, only for selected visibility.")] }
        return AdminSpec(title: "Variables", root: root + "/variables", key: "variables", identity: "name", web: web, fields: fields)
    }
    static func environmentVariables(_ root: String, web: String) -> AdminSpec {
        AdminSpec(title: "Variables", root: root + "/variables", key: "variables", identity: "name", web: web, fields: [FieldDefinition(key: "name", label: "Name", required: true), FieldDefinition(key: "value", label: "Value", type: .multiline, required: true)])
    }
    static func environments(_ repo: String) -> AdminSpec {
        AdminSpec(title: "Environments", root: "/repos/\(repo)/environments", key: "environments", identity: "name", web: "/\(repo)/settings/environments", fields: [FieldDefinition(key: "name", label: "Name", required: true), FieldDefinition(key: "wait_timer", label: "Wait timer (minutes)", type: .number), FieldDefinition(key: "prevent_self_review", label: "Prevent self review", type: .toggle), FieldDefinition(key: "reviewers", label: "Reviewers", type: .json, help: "An array of User or Team objects with numeric IDs."), FieldDefinition(key: "deployment_branch_policy", label: "Deployment branch policy", type: .json)], createMethod: "PUT", editMethod: "PUT", createSuffix: "/{name}", help: "Protection options depend on repository visibility and plan. Branch policy details are also available in the browser.")
    }
    static func caches(_ repo: String) -> AdminSpec { AdminSpec(title: "Caches", root: "/repos/\(repo)/actions/caches", key: "actions_caches", web: "/\(repo)/actions/caches", createMethod: nil, editMethod: nil) }
    static func runnerGroups(_ root: String, web: String) -> AdminSpec {
        AdminSpec(title: "Runner groups", root: root + "/runner-groups", key: "runner_groups", web: web + "/runners", fields: [FieldDefinition(key: "name", label: "Name", required: true), FieldDefinition(key: "visibility", label: "Visibility", type: .choice(["selected", "all", "private"])), FieldDefinition(key: "allows_public_repositories", label: "Allow public repositories", type: .toggle), FieldDefinition(key: "selected_repository_ids", label: "Repository IDs", type: .json), FieldDefinition(key: "runners", label: "Runner IDs", type: .json)])
    }
    static func runnerLabels(root: String, runner: String, web: String) -> AdminSpec {
        AdminSpec(title: "Runner labels", root: root + "/runners/\(runner)/labels", key: "labels", identity: "name", web: web, fields: [FieldDefinition(key: "labels", label: "Labels", type: .csv, required: true)], editMethod: nil)
    }
    static func releases(_ repo: String) -> AdminSpec {
        AdminSpec(title: "Releases", root: "/repos/\(repo)/releases", web: "/\(repo)/releases", fields: [FieldDefinition(key: "tag_name", label: "Tag", required: true), FieldDefinition(key: "target_commitish", label: "Target branch or commit"), FieldDefinition(key: "name", label: "Release title"), FieldDefinition(key: "body", label: "Release notes (Markdown)", type: .multiline), FieldDefinition(key: "draft", label: "Draft", type: .toggle), FieldDefinition(key: "prerelease", label: "Prerelease", type: .toggle), FieldDefinition(key: "generate_release_notes", label: "Generate release notes", type: .toggle)])
    }
    static func webhooks(_ repo: String) -> AdminSpec {
        AdminSpec(title: "Webhooks", root: "/repos/\(repo)/hooks", web: "/\(repo)/settings/hooks", fields: [FieldDefinition(key: "name", label: "Type", type: .choice(["web"])), FieldDefinition(key: "active", label: "Active", type: .toggle), FieldDefinition(key: "events", label: "Events", type: .csv), FieldDefinition(key: "config", label: "Delivery configuration", type: .json, required: true, help: "Object containing url, content_type, and optional secret. Secrets are not cached by this editor.")], help: "Only load metadata. Re-enter a secret when changing it; GitHub returns a redacted value.")
    }
    static func rulesets(_ repo: String) -> AdminSpec {
        AdminSpec(title: "Rulesets", root: "/repos/\(repo)/rulesets", web: "/\(repo)/settings/rules", fields: [FieldDefinition(key: "name", label: "Name", required: true), FieldDefinition(key: "target", label: "Target", type: .choice(["branch", "tag", "push"])), FieldDefinition(key: "enforcement", label: "Enforcement", type: .choice(["active", "disabled", "evaluate"])), FieldDefinition(key: "conditions", label: "Conditions", type: .json), FieldDefinition(key: "rules", label: "Rules", type: .json, required: true), FieldDefinition(key: "bypass_actors", label: "Bypass actors", type: .json)], editMethod: "PUT", help: "Advanced rules use structured configuration. The browser offers the full graphical editor and plan-specific validation.")
    }
}

struct RepositoryAdministration: View {
    let repo: String
    let branch: String
    let repository: JSON
    @Environment(Session.self) private var session
    @State private var editor: EditorDefinition?
    var body: some View {
        List {
            Button("General settings") { editor = EditorDefinition(title: "Repository settings", path: "/repos/\(repo)", method: "PATCH", fields: [FieldDefinition(key: "name", label: "Name", required: true), FieldDefinition(key: "description", label: "Description", type: .multiline), FieldDefinition(key: "homepage", label: "Homepage"), FieldDefinition(key: "default_branch", label: "Default branch"), FieldDefinition(key: "private", label: "Private", type: .toggle), FieldDefinition(key: "has_issues", label: "Issues enabled", type: .toggle), FieldDefinition(key: "has_projects", label: "Projects enabled", type: .toggle), FieldDefinition(key: "has_wiki", label: "Wiki enabled", type: .toggle), FieldDefinition(key: "allow_squash_merge", label: "Squash merging", type: .toggle), FieldDefinition(key: "allow_merge_commit", label: "Merge commits", type: .toggle), FieldDefinition(key: "allow_rebase_merge", label: "Rebase merging", type: .toggle), FieldDefinition(key: "delete_branch_on_merge", label: "Delete merged branches", type: .toggle)], initial: .object(repository.object.filter { ["name", "description", "homepage", "default_branch", "private", "has_issues", "has_projects", "has_wiki", "allow_squash_merge", "allow_merge_commit", "allow_rebase_merge", "delete_branch_on_merge"].contains($0.key) })) }
            Button("Edit topics") { editor = EditorDefinition(title: "Topics", path: "/repos/\(repo)/topics", method: "PUT", fields: [FieldDefinition(key: "names", label: "Topics", type: .csv)], initial: .object(["names": repository["topics"]])) }
            NavigationLink { ResourceList(title: "Collaborators", path: "/repos/\(repo)/collaborators?per_page=100", webPath: "/\(repo)/settings/access", editor: EditorDefinition(title: "Add collaborator", path: "/repos/\(repo)/collaborators/{username}", method: "PUT", fields: [FieldDefinition(key: "username", label: "Username", required: true), FieldDefinition(key: "permission", label: "Permission", type: .choice(["pull", "triage", "push", "maintain", "admin"]))])) } label: { Text("Collaborators") }
            NavigationLink { AdminResourceView(spec: .webhooks(repo)) } label: { Text("Webhooks") }
            NavigationLink { AdminResourceView(spec: .rulesets(repo)) } label: { Text("Rulesets") }
            NavigationLink { SettingsResourceView(title: "Branch protection", path: "/repos/\(repo)/branches/\(URLCoding.segment(branch))/protection", webPath: "/\(repo)/settings/branches", fields: [FieldDefinition(key: "required_status_checks", label: "Required status checks", type: .json, required: true), FieldDefinition(key: "enforce_admins", label: "Enforce for administrators", type: .toggle), FieldDefinition(key: "required_pull_request_reviews", label: "Review requirements", type: .json, required: true), FieldDefinition(key: "restrictions", label: "Push restrictions", type: .json, required: true), FieldDefinition(key: "required_linear_history", label: "Require linear history", type: .toggle)]) } label: { Text("Branch protection: \(branch)") }
            Button("Transfer repository") { editor = EditorDefinition(title: "Transfer \(repo)", path: "/repos/\(repo)/transfer", fields: [FieldDefinition(key: "new_owner", label: "New owner", required: true), FieldDefinition(key: "new_name", label: "New name (optional)"), FieldDefinition(key: "team_ids", label: "Team IDs (optional)", type: .json)], help: "Transfer changes ownership and may require acceptance by the new owner.") }
            ActionMenu(title: "Archive or delete", actions: [APIAction(title: repository["archived"].bool ? "Unarchive \(repo)" : "Archive \(repo)", path: "/repos/\(repo)", method: "PATCH", body: .object(["archived": .bool(!repository["archived"].bool)]), destructive: true), APIAction(title: "Permanently delete \(repo)", path: "/repos/\(repo)", method: "DELETE", destructive: true)])
            Button("All repository settings", systemImage: "safari") { session.browse("/\(repo)/settings") }
        }.navigationTitle("Repository settings").sheet(item: $editor) { EditorView(definition: $0) }
    }
}
