import SwiftUI
import GitHubKit
import Sodium

struct ActionsView: View {
    let repo: String
    @Environment(Session.self) private var session
    var body: some View {
        List {
            NavigationLink { ResourceList(title: "Workflows", path: "/repos/\(repo)/actions/workflows?per_page=100", key: "workflows", kind: .workflow(repo), webPath: "/\(repo)/actions") } label: { Label("Workflows", systemImage: "flowchart") }
            NavigationLink { ResourceList(title: "Workflow runs", path: "/repos/\(repo)/actions/runs?per_page=50", key: "workflow_runs", kind: .run(repo), webPath: "/\(repo)/actions") } label: { Label("Runs", systemImage: "play.circle") }
            NavigationLink { ActionsAdministration(root: "/repos/\(repo)/actions", webPath: "/\(repo)/settings/actions", repo: repo) } label: { Label("Secrets, variables & runners", systemImage: "gearshape.2") }
            NavigationLink { AdminResourceView(spec: .environments(repo)) } label: { Label("Environments", systemImage: "shippingbox") }
            NavigationLink { AdminResourceView(spec: .caches(repo)) } label: { Label("Caches", systemImage: "externaldrive") }
            NavigationLink { ArtifactList(repo: repo) } label: { Label("Artifacts", systemImage: "archivebox") }
            NavigationLink { FileView(repo: repo, branch: "HEAD", item: .object(["type": .string("dir"), "name": .string("Workflows"), "path": .string(".github/workflows")])) } label: { Label("Edit workflow files", systemImage: "doc.badge.gearshape") }
            Button("Actions usage & billing", systemImage: "chart.bar") { session.browse("/settings/billing/usage") }
        }.navigationTitle("Actions")
    }
}

struct WorkflowView: View {
    let repo: String
    let workflow: JSON
    @State private var dispatch = false
    var body: some View {
        ResourceList(title: workflow["name"].string, path: "/repos/\(repo)/actions/workflows/\(workflow["id"].string)/runs?per_page=50", key: "workflow_runs", kind: .run(repo), webPath: "/\(repo)/actions/workflows/\(workflow["path"].string.components(separatedBy: "/").last ?? "")")
            .toolbar {
                Button("Run workflow", systemImage: "play") { dispatch = true }
                ActionMenu(title: "Workflow actions", actions: [APIAction(title: "Enable", path: "/repos/\(repo)/actions/workflows/\(workflow["id"].string)/enable", method: "PUT"), APIAction(title: "Disable", path: "/repos/\(repo)/actions/workflows/\(workflow["id"].string)/disable", method: "PUT", destructive: true)])
            }.sheet(isPresented: $dispatch) { WorkflowDispatchView(repo: repo, workflow: workflow) }
    }
}

struct RunView: View {
    let repo: String
    let run: JSON
    @Environment(Session.self) private var session
    @State private var approval: EditorDefinition?
    var path: String { "/repos/\(repo)/actions/runs/\(run["id"].string)" }
    var body: some View {
        List {
            Section { ResourceRow(value: run) }
            NavigationLink { ResourceList(title: "Jobs & steps", path: path + "/jobs?per_page=100", key: "jobs", kind: .job(repo), webPath: "/\(repo)/actions/runs/\(run["id"].string)") } label: { Label("Jobs & logs", systemImage: "list.bullet.rectangle") }
            NavigationLink { ArtifactList(repo: repo, runID: run["id"].string) } label: { Label("Artifacts", systemImage: "archivebox") }
            NavigationLink { ResourceList(title: "Pending deployments", path: path + "/pending_deployments", webPath: "/\(repo)/actions/runs/\(run["id"].string)") } label: { Label("Deployment approvals", systemImage: "checkmark.shield") }
            Button("Approve or reject deployment") { approval = EditorDefinition(title: "Review deployment", path: path + "/pending_deployments", fields: [FieldDefinition(key: "environment_ids", label: "Environment IDs", type: .json, required: true, help: "Use the numeric IDs shown in pending deployments, as an array."), FieldDefinition(key: "state", label: "Decision", type: .choice(["approved", "rejected"])), FieldDefinition(key: "comment", label: "Comment", type: .multiline, required: true)]) }
            ActionMenu(title: "Control run", actions: [
                APIAction(title: "Re-run all jobs", path: path + "/rerun"),
                APIAction(title: "Re-run failed jobs", path: path + "/rerun-failed-jobs"),
                APIAction(title: "Cancel run", path: path + "/cancel", destructive: true),
                APIAction(title: "Force-cancel run", path: path + "/force-cancel", destructive: true),
                APIAction(title: "Delete run", path: path, method: "DELETE", destructive: true)
            ])
            Button("Open run on GitHub", systemImage: "safari") { session.browse("/\(repo)/actions/runs/\(run["id"].string)") }
        }.navigationTitle("Run #\(run["run_number"].int)").sheet(item: $approval) { EditorView(definition: $0) }
    }
}

struct LogView: View {
    let repo: String
    let job: JSON
    @Environment(Session.self) private var session
    @State private var source = ""
    @State private var search = ""
    @State private var error: String?
    @State private var live = false
    @State private var loading = false
    var body: some View {
        List {
            Section("Job steps") {
                ForEach(job["steps"].array.map { ResourceItem($0) }) { step in ResourceRow(value: step.value) }
            }
            Section("Log") {
                Toggle("Poll for available logs", isOn: $live)
                Text("GitHub exposes downloadable log snapshots. Running jobs may not have a snapshot yet.").font(.caption).foregroundStyle(.secondary)
                if let error { Text(error).foregroundStyle(.red) }
                if loading { ProgressView() }
                ForEach(Array(filtered.enumerated()), id: \.offset) { _, line in ansiText(line).font(.caption.monospaced()).textSelection(.enabled) }
                if source.isEmpty && !loading && error == nil { Text("No logs available yet.").foregroundStyle(.secondary) }
            }
        }.navigationTitle(job["name"].string).navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Find in log")
            .toolbar {
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await load() } }
                ShareLink(item: source)
                Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: source]], options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)]) }
            }.task { await load() }.task(id: live) {
                guard live else { return }
                while !Task.isCancelled { do { try await Task.sleep(for: .seconds(30)); await load() } catch { break } }
            }
    }
    private var filtered: [String] { let lines = source.components(separatedBy: .newlines); return search.isEmpty ? lines : lines.filter { $0.localizedCaseInsensitiveContains(search) } }
    private func ansiText(_ line: String) -> Text {
        let colors: [Color] = [.primary, .red, .green, .orange, .blue, .purple, .cyan, .primary]
        return ANSI.parse(line).reduce(Text("")) { result, span in
            let part = Text(span.text).foregroundColor(span.color.map { colors[$0] } ?? .primary)
            return result + (span.bold ? part.bold() : part)
        }
    }
    private func load() async {
        guard !loading else { return }; loading = true; defer { loading = false }
        do {
            let response = try await session.request("/repos/\(repo)/actions/jobs/\(job["id"].string)/logs", accept: "application/vnd.github+json", cache: false)
            source = String(decoding: response.data.suffix(2 * 1024 * 1024), as: UTF8.self); error = nil
        } catch { self.error = error.localizedDescription }
    }
}

struct WorkflowDispatchView: View {
    let repo: String
    let workflow: JSON
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var branch = "main"
    @State private var definition: WorkflowDefinition?
    @State private var values: [String: String] = [:]
    @State private var error: String?
    @State private var busy = false
    var body: some View {
        NavigationStack {
            Form {
                TextField("Branch or tag", text: $branch).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Load inputs from this ref") { Task { await load() } }
                if let definition {
                    if !definition.supportsDispatch { Text("This workflow does not declare workflow_dispatch.").foregroundStyle(.secondary) }
                    if definition.needsAdvancedEditor { Text("This workflow uses complex YAML. Use the browser to ensure every input is included.").foregroundStyle(.orange); Button("Open workflow on GitHub") { session.browse("/\(repo)/actions/workflows/\(workflow["path"].string.components(separatedBy: "/").last ?? "")") } }
                    ForEach(definition.inputs) { input in
                        Section {
                            if input.type == "boolean" { Toggle(input.id, isOn: Binding(get: { values[input.id] == "true" }, set: { values[input.id] = String($0) })) }
                            else if input.type == "choice" { Picker(input.id, selection: binding(input.id)) { ForEach(input.options, id: \.self) { Text($0).tag($0) } } }
                            else { TextField(input.id, text: binding(input.id)).textInputAutocapitalization(.never).autocorrectionDisabled() }
                        } header: { Text(input.id + (input.required ? " *" : "")) } footer: { Text(input.description) }
                    }
                    Button(busy ? "Starting…" : "Run workflow") { Task { await dispatch() } }.disabled(busy || !definition.supportsDispatch || definition.needsAdvancedEditor)
                } else { ProgressView("Loading workflow definition…") }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Run workflow").toolbar { Button("Done") { dismiss() } }.task { await load() }
        }
    }
    private func binding(_ key: String) -> Binding<String> { Binding(get: { values[key] ?? "" }, set: { values[key] = $0 }) }
    private func load() async {
        do {
            let file = try await session.request("/repos/\(repo)/contents/\(URLCoding.path(workflow["path"].string))?" + URLCoding.query(["ref": branch]), cache: false).json
            let parsed = WorkflowDefinition.parse(decodeContent(file)); definition = parsed
            values = Dictionary(uniqueKeysWithValues: parsed.inputs.map { ($0.id, $0.defaultValue.isEmpty && $0.type == "choice" ? $0.options.first ?? "" : $0.type == "boolean" && $0.defaultValue.isEmpty ? "false" : $0.defaultValue) }); error = nil
        } catch { self.error = error.localizedDescription }
    }
    private func dispatch() async {
        guard let definition else { return }; busy = true; defer { busy = false }
        do { _ = try await session.request("/repos/\(repo)/actions/workflows/\(workflow["id"].string)/dispatches", method: "POST", body: .object(["ref": .string(branch), "inputs": try definition.values(values)])); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}

struct ActionsAdministration: View {
    let root: String
    let webPath: String
    var repo: String? = nil
    var body: some View {
        List {
            NavigationLink { SecretList(root: root + "/secrets", webPath: webPath + "/secrets", organization: root.hasPrefix("/orgs/")) } label: { Label("Secrets", systemImage: "key") }
            NavigationLink { AdminResourceView(spec: .variables(root, web: webPath)) } label: { Label("Variables", systemImage: "textformat.abc") }
            NavigationLink { RunnerList(root: root, webPath: webPath + "/runners") } label: { Label("Self-hosted runners", systemImage: "server.rack") }
            NavigationLink { SettingsResourceView(title: "Actions permissions", path: root + "/permissions", webPath: webPath, fields: [FieldDefinition(key: "enabled", label: "Enabled", type: .toggle), FieldDefinition(key: "allowed_actions", label: "Allowed actions", type: .choice(["all", "local_only", "selected"]))]) } label: { Label("Permissions", systemImage: "lock.shield") }
            NavigationLink { SettingsResourceView(title: "Workflow permissions", path: root + "/permissions/workflow", webPath: webPath, fields: [FieldDefinition(key: "default_workflow_permissions", label: "Default permissions", type: .choice(["read", "write"])), FieldDefinition(key: "can_approve_pull_request_reviews", label: "Can approve pull requests", type: .toggle)]) } label: { Label("Workflow token permissions", systemImage: "checkmark.shield") }
            if root.hasPrefix("/orgs/") { NavigationLink { AdminResourceView(spec: .runnerGroups(root, web: webPath)) } label: { Label("Runner groups", systemImage: "rectangle.3.group") } }
        }.navigationTitle("Actions settings")
    }
}

struct RunnerList: View {
    let root: String
    let webPath: String
    @Environment(Session.self) private var session
    @State private var runners: [ResourceItem] = []
    @State private var error: String?
    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.red) }
            ForEach(runners) { runner in
                NavigationLink {
                    List {
                        ResourceRow(value: runner.value)
                        LabeledContent("Busy", value: runner.value["busy"].bool ? "Yes" : "No")
                        NavigationLink { AdminResourceView(spec: .runnerLabels(root: root, runner: runner.value["id"].string, web: webPath)) } label: { Text("Labels") }
                        ActionMenu(title: "Runner actions", actions: [APIAction(title: "Remove runner \(runner.value["name"].string)", path: root + "/runners/\(runner.value["id"].string)", method: "DELETE", destructive: true)])
                    }.navigationTitle(runner.value["name"].string)
                } label: { ResourceRow(value: runner.value) }
            }
            if runners.isEmpty && error == nil { ContentUnavailableView("No runners", systemImage: "server.rack") }
            ActionMenu(title: "Create registration token", actions: [APIAction(title: "Create one-hour registration token", path: root + "/runners/registration-token")])
            Button("Open runner settings") { session.browse(webPath) }
        }.navigationTitle("Self-hosted runners").task { await load() }.refreshable { await load() }
    }
    private func load() async { do { runners = try await session.request(root + "/runners?per_page=100").json["runners"].array.map { ResourceItem($0) }; error = nil } catch { self.error = error.localizedDescription } }
}

struct SecretList: View {
    let root: String
    let webPath: String
    var organization = false
    @Environment(Session.self) private var session
    @State private var secrets: [ResourceItem] = []
    @State private var error: String?
    @State private var selected: ResourceItem?
    var body: some View {
        List {
            Text("Secret values are never returned by GitHub. Updates are encrypted with the resource's public key.").font(.footnote).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.red) }
            ForEach(secrets) { secret in
                HStack {
                    Button(secret.value["name"].string) { selected = secret }
                    Spacer()
                    ActionMenu(title: "Delete", actions: [APIAction(title: "Delete secret \(secret.value["name"].string)", path: root + "/\(URLCoding.segment(secret.value["name"].string))", method: "DELETE", destructive: true)], onSuccess: { Task { await load() } })
                }
            }
            Button("Open secret settings") { session.browse(webPath) }
        }.navigationTitle("Secrets").toolbar { Button("New secret", systemImage: "plus") { selected = ResourceItem(.object(["name": .string("")])) } }
            .task { await load() }.refreshable { await load() }
            .sheet(item: $selected, onDismiss: { Task { await load() } }) { item in SecretEditor(root: root, organization: organization, existingName: item.value["name"].string) }
    }
    private func load() async { do { secrets = try await session.request(root + "?per_page=100").json["secrets"].array.map { ResourceItem($0) }; error = nil } catch { self.error = error.localizedDescription } }
}

struct SecretEditor: View {
    let root: String
    let organization: Bool
    let existingName: String
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var value = ""
    @State private var visibility = "private"
    @State private var selectedIDs = ""
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                TextField("Secret name", text: $name).textInputAutocapitalization(.characters).autocorrectionDisabled().disabled(!existingName.isEmpty)
                SecureField("Secret value", text: $value).textInputAutocapitalization(.never).autocorrectionDisabled()
                if organization { Picker("Visibility", selection: $visibility) { Text("Private repositories").tag("private"); Text("All repositories").tag("all"); Text("Selected repositories").tag("selected") }; if visibility == "selected" { TextField("Repository numeric IDs, comma-separated", text: $selectedIDs) } }
                if let error { Text(error).foregroundStyle(.red) }
                Button(busy ? "Encrypting and saving…" : "Save secret") { Task { await save() } }.disabled(name.isEmpty || value.isEmpty || busy)
            }.navigationTitle("Encrypted secret").toolbar { Button("Cancel") { value = ""; dismiss() } }.onAppear { name = existingName }
        }.onDisappear { value = "" }.interactiveDismissDisabled(busy)
    }
    private func save() async {
        busy = true; defer { busy = false }
        do {
            let key = try await session.request(root + "/public-key", cache: false).json
            guard let publicKey = Data(base64Encoded: key["key"].string), publicKey.count == 32,
                  let encrypted = Sodium().box.seal(message: Array(value.utf8), recipientPublicKey: Array(publicKey)) else { throw GitHubError.malformedResponse }
            var body: [String: JSON] = ["encrypted_value": .string(Data(encrypted).base64EncodedString()), "key_id": key["key_id"]]
            if organization { body["visibility"] = .string(visibility); if visibility == "selected" { body["selected_repository_ids"] = .array(try selectedIDs.split(separator: ",").map { text in guard let number = Double(text.trimmingCharacters(in: .whitespaces)) else { throw GitHubError.http(422, "Repository IDs must be numeric.") }; return .number(number) }) } }
            _ = try await session.request(root + "/\(URLCoding.segment(name))", method: "PUT", body: .object(body)); value = ""; dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
