import SwiftUI
import UniformTypeIdentifiers
import GitHubKit

struct RepositoryView: View {
    let repository: JSON
    @Environment(Session.self) private var session
    @State private var readme = ""
    @State private var readmeError: String?
    @State private var branch: String
    @State private var branches: [String] = []
    @State private var editor: EditorDefinition?
    init(repository: JSON) { self.repository = repository; _branch = State(initialValue: repository["default_branch"].string.isEmpty ? "main" : repository["default_branch"].string) }
    var repo: String { repository["full_name"].string }
    var api: String { "/repos/" + repo }
    var body: some View {
        List {
            Section { ResourceRow(value: repository); if !branches.isEmpty { Picker("Branch", selection: $branch) { ForEach(branches, id: \.self) { Text($0).tag($0) } } } }
            Section("Repository") {
                NavigationLink { ResourceList(title: "Code", path: api + "/contents?" + URLCoding.query(["ref": branch]), kind: .file(repo, branch), webPath: "/\(repo)/tree/\(URLCoding.segment(branch))") } label: { Label("Code", systemImage: "chevron.left.forwardslash.chevron.right") }
                NavigationLink { RepositoryIssuesView(repo: repo) } label: { Label("Issues", systemImage: "circle.dotted") }
                NavigationLink { RepositoryIssuesView(repo: repo, pulls: true) } label: { Label("Pull requests", systemImage: "arrow.triangle.pull") }
                NavigationLink { ActionsView(repo: repo) } label: { Label("Actions", systemImage: "play.circle") }
                NavigationLink { ResourceList(title: "Commits", path: api + "/commits?" + URLCoding.query(["sha": branch, "per_page": "50"]), webPath: "/\(repo)/commits/\(URLCoding.segment(branch))") } label: { Label("Commit history", systemImage: "clock.arrow.circlepath") }
                NavigationLink { CompareView(repo: repo, defaultBranch: branch) } label: { Label("Compare branches", systemImage: "arrow.triangle.branch") }
                NavigationLink { RepositoryExtras(repo: repo) } label: { Label("Releases, projects & more", systemImage: "square.grid.2x2") }
                NavigationLink { RepositoryAdministration(repo: repo, branch: branch, repository: repository) } label: { Label("Repository settings", systemImage: "gearshape") }
            }
            Section("Files") {
                Button("Create a file", systemImage: "doc.badge.plus") { editor = .file(repo: repo, branch: branch) }
                NavigationLink { UploadFileView(repo: repo, branch: branch) } label: { Label("Upload from Files", systemImage: "square.and.arrow.up") }
            }
            Section("README") {
                if !readme.isEmpty { MarkdownView(text: readme) }
                else if let readmeError { Text(readmeError).foregroundStyle(.secondary); Button("Retry") { Task { await loadReadme() } } }
                else { ProgressView() }
            }
        }.navigationTitle(repository["name"].string).navigationBarTitleDisplayMode(.inline)
            .toolbar { ActionMenu(title: "Repository actions", actions: [
                APIAction(title: "Star", path: "/user/starred/\(repo)", method: "PUT"),
                APIAction(title: "Unstar", path: "/user/starred/\(repo)", method: "DELETE"),
                APIAction(title: "Watch", path: api + "/subscription", method: "PUT", body: .object(["subscribed": .bool(true), "ignored": .bool(false)])),
                APIAction(title: "Mute", path: api + "/subscription", method: "PUT", body: .object(["subscribed": .bool(false), "ignored": .bool(true)])),
                APIAction(title: "Fork", path: api + "/forks")
            ]) }
            .sheet(item: $editor) { EditorView(definition: $0) }
            .task { do { branches = try await session.request(api + "/branches?per_page=100").json.array.map { $0["name"].string } } catch { branches = [branch] }; await loadReadme() }
            .task(id: branch) { await loadReadme() }
    }
    private func loadReadme() async {
        readme = ""; readmeError = nil
        do { let value = try await session.request(api + "/readme?" + URLCoding.query(["ref": branch])).json; readme = decodeContent(value) }
        catch GitHubError.notFound { readmeError = "No README on this branch." }
        catch { readmeError = error.localizedDescription }
    }
}

func decodeContent(_ value: JSON) -> String {
    let encoded = value["content"].string.filter { !$0.isWhitespace }
    return Data(base64Encoded: encoded).flatMap { String(data: $0, encoding: .utf8) } ?? ""
}

struct FileView: View {
    let repo: String
    let branch: String
    let item: JSON
    @Environment(Session.self) private var session
    @State private var content: JSON = .null
    @State private var error: String?
    @State private var editor: EditorDefinition?
    var api: String { "/repos/\(repo)/contents/\(URLCoding.path(item["path"].string))" }
    var body: some View {
        Group {
            if item["type"].string == "dir" { ResourceList(title: item["name"].string, path: api + "?" + URLCoding.query(["ref": branch]), kind: .file(repo, branch), webPath: "/\(repo)/tree/\(URLCoding.segment(branch))/\(URLCoding.path(item["path"].string))") }
            else if let error { FailureView(message: error) { Task { await load() } } }
            else if content.isNull { ProgressView("Loading file…") }
            else {
                ScrollView {
                    let text = decodeContent(content)
                    if text.isEmpty { ContentUnavailableView("Preview unavailable", systemImage: "doc", description: Text("Binary or large files can be opened in the browser.")); Button("Open file") { session.browse("/\(repo)/blob/\(URLCoding.segment(branch))/\(URLCoding.path(item["path"].string))") } }
                    else if item["name"].string.lowercased().hasSuffix(".md") { MarkdownView(text: text).padding() }
                    else { MarkdownView(text: "```\(language)\n\(text)\n```").padding() }
                }
                .toolbar {
                    Button("Edit", systemImage: "pencil") { editor = .file(repo: repo, branch: branch, path: item["path"].string, content: content) }
                    ActionMenu(title: "File actions", actions: [APIAction(title: "Delete file", path: api, method: "DELETE", body: .object(["message": .string("Delete \(item["path"].string)"), "sha": content["sha"], "branch": .string(branch)]), destructive: true)])
                }
            }
        }.navigationTitle(item["name"].string).navigationBarTitleDisplayMode(.inline).task { if item["type"].string != "dir" { await load() } }
            .toolbar { if item["type"].string != "dir" { Button("Open file on GitHub", systemImage: "safari") { session.browse("/\(repo)/blob/\(URLCoding.segment(branch))/\(URLCoding.path(item["path"].string))") } } }
            .sheet(item: $editor, onDismiss: { Task { await load() } }) { EditorView(definition: $0) }
    }
    private var language: String {
        let ext = item["name"].string.components(separatedBy: ".").last ?? ""
        return ["swift": "swift", "yml": "yaml", "yaml": "yaml", "js": "javascript", "ts": "typescript", "py": "python", "json": "json", "sh": "bash" ][ext] ?? ext
    }
    private func load() async { error = nil; do { content = try await session.request(api + "?" + URLCoding.query(["ref": branch])).json } catch { self.error = error.localizedDescription } }
}

extension EditorDefinition {
    static func file(repo: String, branch: String, path: String = "", content: JSON = .null) -> EditorDefinition {
        var initial: [String: JSON] = ["path": .string(path), "message": .string(path.isEmpty ? "Create a file" : "Update \(path)"), "branch": .string(branch), "content": .string(decodeContent(content))]
        if !content["sha"].isNull { initial["sha"] = content["sha"] }
        return EditorDefinition(title: path.isEmpty ? "Create file" : "Edit file", path: "/repos/\(repo)/contents/{path}", method: "PUT", fields: [
            FieldDefinition(key: "path", label: "File path", required: true, help: "Include directories, for example .github/workflows/build.yml."),
            FieldDefinition(key: "content", label: "Contents", type: .multiline),
            FieldDefinition(key: "message", label: "Commit message", required: true),
            FieldDefinition(key: "branch", label: "Branch", required: true)
        ], initial: .object(initial), help: "The change creates a commit on the selected branch. Editing uses the loaded file SHA to detect conflicts.", transform: { value in
            var object = value.object; object["content"] = .string(Data(value["content"].string.utf8).base64EncodedString()); object.removeValue(forKey: "path"); return .object(object)
        })
    }
}

struct UploadFileView: View {
    let repo: String
    let branch: String
    @Environment(Session.self) private var session
    @State private var importing = false
    @State private var fileData: Data?
    @State private var path = ""
    @State private var message = "Upload file"
    @State private var status: String?
    @State private var busy = false
    var body: some View {
        Form {
            Button("Choose from Files", systemImage: "folder") { importing = true }
            TextField("Repository file path", text: $path).textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("Commit message", text: $message)
            LabeledContent("Branch", value: branch)
            if let fileData { LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: Int64(fileData.count), countStyle: .file)) }
            Button(busy ? "Uploading…" : "Commit upload") { Task { await upload() } }.disabled(fileData == nil || path.isEmpty || message.isEmpty || busy)
            if let status { Text(status).textSelection(.enabled) }
        }.navigationTitle("Upload file").fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { result in
            do {
                let url = try result.get(); let granted = url.startAccessingSecurityScopedResource(); defer { if granted { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 8 * 1024 * 1024 else { throw GitHubError.oversized }
                fileData = try Data(contentsOf: url); path = url.lastPathComponent; status = nil
            } catch { status = error.localizedDescription }
        }
    }
    private func upload() async {
        guard let fileData else { return }; busy = true; defer { busy = false }
        do { _ = try await session.request("/repos/\(repo)/contents/\(URLCoding.path(path))", method: "PUT", body: .object(["message": .string(message), "branch": .string(branch), "content": .string(fileData.base64EncodedString())])); status = "File committed successfully."; self.fileData = nil }
        catch { status = error.localizedDescription }
    }
}

struct CompareView: View {
    let repo: String
    let defaultBranch: String
    @Environment(Session.self) private var session
    @State private var base = ""
    @State private var head = ""
    @State private var comparison: JSON = .null
    @State private var error: String?
    var body: some View {
        List {
            TextField("Base branch", text: $base).textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("Head branch", text: $head).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Compare") { Task { do { comparison = try await session.request("/repos/\(repo)/compare/\(URLCoding.segment(base))...\(URLCoding.segment(head))").json; error = nil } catch { self.error = error.localizedDescription } } }.disabled(base.isEmpty || head.isEmpty)
            if let error { Text(error).foregroundStyle(.red) }
            if !comparison.isNull { LabeledContent("Status", value: comparison["status"].string); LabeledContent("Ahead", value: comparison["ahead_by"].string); ForEach(comparison["files"].array.map { ResourceItem($0) }) { file in NavigationLink(file.value["filename"].string) { DiffView(patch: file.value["patch"].string) } } }
        }.navigationTitle("Compare").onAppear { if base.isEmpty { base = defaultBranch } }
            .toolbar { Button("Open compare on GitHub", systemImage: "safari") { session.browse(head.isEmpty ? "/\(repo)/compare" : "/\(repo)/compare/\(URLCoding.segment(base))...\(URLCoding.segment(head))") } }
    }
}

struct CreateRepositoryView: View {
    @Environment(Session.self) private var session
    @State private var owner = ""
    @State private var owners: [String] = []
    @State private var name = ""
    @State private var description = ""
    @State private var visibility = "public"
    @State private var template = ""
    @State private var allBranches = false
    @State private var readme = true
    @State private var ignore = ""
    @State private var license = ""
    @State private var branch = "main"
    @State private var ignores: [String] = []
    @State private var licenses: [ResourceItem] = []
    @State private var availability: String?
    @State private var error: String?
    @State private var busy = false
    @State private var created: JSON = .null
    @State private var check: Task<Void, Never>?
    var body: some View {
        Form {
            Section("Destination") {
                Picker("Owner", selection: $owner) { ForEach(owners, id: \.self) { Text($0).tag($0) } }
                TextField("Repository name", text: $name).textInputAutocapitalization(.never).autocorrectionDisabled()
                if let availability { Text(availability).font(.caption).foregroundStyle(.secondary) }
                TextField("Description", text: $description, axis: .vertical)
                Picker("Visibility", selection: $visibility) { Text("Public").tag("public"); Text("Private").tag("private"); if owner != session.login { Text("Internal (enterprise only)").tag("internal") } }
            }
            Section("Template") {
                TextField("Optional owner/template-repository", text: $template).textInputAutocapitalization(.never).autocorrectionDisabled()
                if !template.isEmpty { Toggle("Include all branches", isOn: $allBranches); Text("Template files are copied. Initialization choices below are added only if the file is absent.").font(.caption) }
            }
            Section("Initialize") {
                Toggle("Add a README", isOn: $readme)
                Picker(".gitignore template", selection: $ignore) { Text("None").tag(""); ForEach(ignores, id: \.self) { Text($0).tag($0) } }
                Picker("License", selection: $license) { Text("None").tag(""); ForEach(licenses) { Text($0.value["name"].string).tag($0.value["key"].string) } }
                TextField("Default branch", text: $branch).textInputAutocapitalization(.never).autocorrectionDisabled()
                Text("A custom default branch can be set after the repository has an initial commit. Organization policy may restrict creation.").font(.caption).foregroundStyle(.secondary)
            }
            if let error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
            if !created.isNull { NavigationLink("Open created repository") { RepositoryView(repository: created) } }
            Button(busy ? "Creating…" : "Create repository") { Task { await create() } }.disabled(name.isEmpty || owner.isEmpty || busy || !created.isNull)
        }.navigationTitle("New repository")
            .toolbar { Button("Open New Repository on GitHub", systemImage: "safari") { session.browse("/new") } }
            .task {
                owner = session.login; owners = [session.login]
                do { owners += try await session.request("/user/orgs?per_page=100").json.array.map { $0["login"].string }; ignores = try await session.request("/gitignore/templates").json.array.map(\.string); licenses = try await session.request("/licenses").json.array.map { ResourceItem($0) } }
                catch { self.error = "Some creation options could not be loaded: \(error.localizedDescription)" }
            }.onChange(of: name) { _, _ in checkName() }.onChange(of: owner) { _, _ in checkName() }.onDisappear { check?.cancel() }
    }
    private func checkName() {
        check?.cancel(); availability = nil
        guard !name.isEmpty && !owner.isEmpty else { return }
        let checkedName = name; let checkedOwner = owner
        check = Task {
            do { try await Task.sleep(for: .milliseconds(500)); _ = try await session.request("/repos/\(URLCoding.segment(checkedOwner))/\(URLCoding.segment(checkedName))", cache: false); availability = "A visible repository already uses this name." }
            catch is CancellationError { }
            catch GitHubError.notFound { availability = "No accessible repository found. Creation confirms availability." }
            catch { availability = "Availability could not be checked." }
        }
    }
    private func create() async {
        busy = true; error = nil; defer { busy = false }
        do {
            let fromTemplate = !template.trimmingCharacters(in: .whitespaces).isEmpty
            var body: [String: JSON] = ["name": .string(name), "description": .string(description), "private": .bool(visibility != "public")]
            let path: String
            if fromTemplate {
                guard template.split(separator: "/").count == 2 else { throw GitHubError.http(422, "Enter a template as owner/repository.") }
                path = "/repos/\(URLCoding.path(template))/generate"; body["owner"] = .string(owner); body["include_all_branches"] = .bool(allBranches)
                guard visibility != "internal" else { throw GitHubError.http(422, "Template generation supports public or private visibility. Change visibility in settings afterward.") }
            } else {
                path = owner == session.login ? "/user/repos" : "/orgs/\(URLCoding.segment(owner))/repos"
                body["auto_init"] = .bool(readme)
                if owner != session.login { body["visibility"] = .string(visibility) }
                if !ignore.isEmpty { body["gitignore_template"] = .string(ignore) }
                if !license.isEmpty { body["license_template"] = .string(license) }
            }
            created = try await session.request(path, method: "POST", body: .object(body)).json
            let repo = created["full_name"].string
            // Poll template generation briefly; keep the created repository reachable on partial failure.
            if fromTemplate {
                for attempt in 0..<5 {
                    let info = try await session.request("/repos/\(repo)", cache: false).json
                    if info["size"].int > 0 || !info["default_branch"].string.isEmpty { created = info; break }
                    try await Task.sleep(for: .seconds(attempt + 1))
                }
                if readme { try await addIfMissing(repo, path: "README.md", text: "# \(name)\n\n\(description)\n") }
                if !ignore.isEmpty { let text = try await session.request("/gitignore/templates/\(URLCoding.segment(ignore))").json["source"].string; try await addIfMissing(repo, path: ".gitignore", text: text) }
                if !license.isEmpty { let text = try await session.request("/licenses/\(URLCoding.segment(license))").json["body"].string; try await addIfMissing(repo, path: "LICENSE", text: text) }
            }
            let old = created["default_branch"].string
            if !branch.isEmpty && branch != old && (readme || !ignore.isEmpty || !license.isEmpty || fromTemplate) {
                let reference = try await session.request("/repos/\(repo)/git/ref/heads/\(URLCoding.path(old))", cache: false).json
                _ = try await session.request("/repos/\(repo)/git/refs", method: "POST", body: .object(["ref": .string("refs/heads/\(branch)"), "sha": reference.at("object.sha")]))
                created = try await session.request("/repos/\(repo)", method: "PATCH", body: .object(["default_branch": .string(branch)])).json
            }
        } catch { self.error = created.isNull ? error.localizedDescription : "Repository created, but initialization needs attention: \(error.localizedDescription)" }
    }
    private func addIfMissing(_ repo: String, path: String, text: String) async throws {
        do { _ = try await session.request("/repos/\(repo)/contents/\(URLCoding.path(path))", cache: false); return }
        catch GitHubError.notFound { }
        _ = try await session.request("/repos/\(repo)/contents/\(URLCoding.path(path))", method: "PUT", body: .object(["message": .string("Initialize \(path)"), "content": .string(Data(text.utf8).base64EncodedString())]))
    }
}
