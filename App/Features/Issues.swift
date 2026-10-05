import SwiftUI
import GitHubKit

extension EditorDefinition {
    static func issue(_ repo: String, number: Int? = nil, initial: JSON = .null) -> EditorDefinition {
        let fields = [FieldDefinition(key: "title", label: "Title", required: true),
            FieldDefinition(key: "body", label: "Description (Markdown)", type: .multiline),
            FieldDefinition(key: "labels", label: "Labels", type: .csv, help: "Comma-separated existing label names."),
            FieldDefinition(key: "assignees", label: "Assignees", type: .csv, help: "Comma-separated usernames."),
            FieldDefinition(key: "milestone", label: "Milestone number", type: .number)]
        var data = initial.object
        if let labels = data["labels"] { data["labels"] = .array(labels.array.map { $0["name"] }) }
        if let assignees = data["assignees"] { data["assignees"] = .array(assignees.array.map { $0["login"] }) }
        if !initial["milestone"].isNull { data["milestone"] = initial.at("milestone.number") }
        // Only permitted write fields; never echo a GET resource wholesale into a mutation.
        data = data.filter { key, _ in fields.contains { $0.key == key } }
        return EditorDefinition(title: number == nil ? "New issue" : "Edit issue", path: "/repos/\(repo)/issues" + (number.map { "/\($0)" } ?? ""), method: number == nil ? "POST" : "PATCH", fields: fields, initial: .object(data))
    }
    static func pull(_ repo: String, branch: String) -> EditorDefinition {
        EditorDefinition(title: "New pull request", path: "/repos/\(repo)/pulls", fields: [
            FieldDefinition(key: "title", label: "Title", required: true),
            FieldDefinition(key: "head", label: "Head branch", required: true, help: "Use owner:branch for a fork."),
            FieldDefinition(key: "base", label: "Base branch", required: true),
            FieldDefinition(key: "body", label: "Description (Markdown)", type: .multiline),
            FieldDefinition(key: "draft", label: "Draft", type: .toggle)
        ], initial: .object(["base": .string(branch)]))
    }
}

struct IssueDetailView: View {
    let repo: String
    let number: Int
    let pull: Bool
    @Environment(Session.self) private var session
    @State private var issue: JSON = .null
    @State private var details: JSON = .null
    @State private var comments: [ResourceItem] = []
    @State private var error: String?
    @State private var editor: EditorDefinition?
    @State private var graphqlResult: String?
    var api: String { "/repos/\(repo)" }
    var body: some View {
        Group {
            if issue.isNull, let error { FailureView(message: error) { Task { await load() } } }
            else if issue.isNull { ProgressView("Loading conversation…") }
            else {
                List {
                    Section { ResourceRow(value: issue); MarkdownView(text: issue["body"].string) }
                    if let error { Text(error).foregroundStyle(.red) }
                    Section("Organize") {
                        Button("Edit title, description & metadata", systemImage: "pencil") { editor = .issue(repo, number: number, initial: issue) }
                        NavigationLink { ResourceList(title: "Labels", path: api + "/labels?per_page=100", webPath: "/\(repo)/labels", editor: EditorDefinition(title: "New label", path: api + "/labels", fields: [FieldDefinition(key: "name", label: "Name", required: true), FieldDefinition(key: "color", label: "Color (six hex digits)", required: true), FieldDefinition(key: "description", label: "Description")])) } label: { Label("Labels", systemImage: "tag") }
                        NavigationLink { ResourceList(title: "Milestones", path: api + "/milestones?state=all&per_page=100", webPath: "/\(repo)/milestones", editor: EditorDefinition(title: "New milestone", path: api + "/milestones", fields: [FieldDefinition(key: "title", label: "Title", required: true), FieldDefinition(key: "description", label: "Description", type: .multiline), FieldDefinition(key: "due_on", label: "Due date (ISO 8601)")])) } label: { Label("Milestones", systemImage: "flag") }
                        if !pull { NavigationLink { ResourceList(title: "Sub-issues", path: api + "/issues/\(number)/sub_issues?per_page=100", kind: .issue(repo), webPath: "/\(repo)/issues/\(number)") } label: { Label("Sub-issues", systemImage: "list.bullet.indent") } }
                        reactionMenu
                    }
                    if pull { pullSection }
                    Section("Conversation") {
                        ForEach(comments) { comment in
                            VStack(alignment: .leading, spacing: 8) { Text(comment.value.at("user.login").string).font(.headline); MarkdownView(text: comment.value["body"].string) }
                        }
                        Button("Reply", systemImage: "bubble.left") { editor = EditorDefinition(title: "Add comment", path: api + "/issues/\(number)/comments", fields: [FieldDefinition(key: "body", label: "Comment (Markdown)", type: .multiline, required: true)]) }
                        NavigationLink { ResourceList(title: "All comments", path: api + "/issues/\(number)/comments?per_page=100", webPath: "/\(repo)/\(pull ? "pull" : "issues")/\(number)") } label: { Text("Browse all comments") }
                    }
                }.refreshable { await load() }
            }
        }.navigationTitle("\(pull ? "PR" : "Issue") #\(number)").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ActionMenu(title: "Conversation actions", actions: [
                    APIAction(title: issue["state"].string == "closed" ? "Reopen" : "Close", path: api + "/issues/\(number)", method: "PATCH", body: .object(["state": .string(issue["state"].string == "closed" ? "open" : "closed")])),
                    APIAction(title: "Lock conversation", path: api + "/issues/\(number)/lock", method: "PUT", body: .object(["lock_reason": .string("resolved")])),
                    APIAction(title: "Unlock conversation", path: api + "/issues/\(number)/lock", method: "DELETE")
                ], onSuccess: { Task { await load() } })
                Button("Open on GitHub", systemImage: "safari") { session.browse("/\(repo)/\(pull ? "pull" : "issues")/\(number)") }
            }
            .sheet(item: $editor, onDismiss: { Task { await load() } }) { EditorView(definition: $0) }
            .alert("Pull request", isPresented: Binding(get: { graphqlResult != nil }, set: { if !$0 { graphqlResult = nil } })) { Button("OK") { graphqlResult = nil } } message: { Text(graphqlResult ?? "") }
            .task { await load() }
    }
    private var reactionMenu: some View {
        Menu("Add reaction", systemImage: "face.smiling") {
            ForEach(["+1", "-1", "laugh", "confused", "heart", "hooray", "rocket", "eyes"], id: \.self) { reaction in
                Button(reaction) { Task { do { _ = try await session.request(api + "/issues/\(number)/reactions", method: "POST", body: .object(["content": .string(reaction)])) } catch { self.error = error.localizedDescription } } }
            }
        }
    }
    private var pullSection: some View {
        Section("Pull request") {
            LabeledContent("Branches", value: "\(details.at("head.ref").string) → \(details.at("base.ref").string)")
            NavigationLink { PullDiffView(repo: repo, number: number, sha: details.at("head.sha").string) } label: { Label("Changed files & inline comments", systemImage: "doc.text.magnifyingglass") }
            NavigationLink { ResourceList(title: "Checks", path: api + "/commits/\(details.at("head.sha").string)/check-runs?per_page=100", key: "check_runs", webPath: "/\(repo)/pull/\(number)/checks") } label: { Label("Checks", systemImage: "checkmark.seal") }
            NavigationLink { ResourceList(title: "Reviews", path: api + "/pulls/\(number)/reviews?per_page=100", webPath: "/\(repo)/pull/\(number)") } label: { Label("Reviews", systemImage: "checkmark.bubble") }
            Button("Submit a review") { editor = EditorDefinition(title: "Review", path: api + "/pulls/\(number)/reviews", fields: [FieldDefinition(key: "event", label: "Decision", type: .choice(["COMMENT", "APPROVE", "REQUEST_CHANGES"])), FieldDefinition(key: "body", label: "Review (Markdown)", type: .multiline)], initial: .object(["commit_id": details.at("head.sha")])) }
            ActionMenu(title: "Merge pull request", actions: ["merge", "squash", "rebase"].map { method in APIAction(title: "Merge using \(method)", path: api + "/pulls/\(number)/merge", method: "PUT", body: .object(["merge_method": .string(method), "sha": details.at("head.sha")])) }, onSuccess: { Task { await load() } })
            Menu("Automatic merging") {
                Button("Enable auto-merge (squash)") { mutate("enablePullRequestAutoMerge", input: "pullRequestId:$id,mergeMethod:SQUASH") }
                Button("Disable auto-merge") { mutate("disablePullRequestAutoMerge", input: "pullRequestId:$id") }
                Button("Join merge queue") { mutate("enqueuePullRequest", input: "pullRequestId:$id") }
                Button("Leave merge queue") { mutate("dequeuePullRequest", input: "pullRequestId:$id") }
            }
        }
    }
    private func mutate(_ name: String, input: String) {
        Task {
            do { _ = try await session.graphql("mutation($id:ID!){\(name)(input:{\(input)}){clientMutationId}}", variables: .object(["id": details["node_id"]])); graphqlResult = "Request completed. Repository policies still apply." }
            catch { graphqlResult = error.localizedDescription }
        }
    }
    private func load() async {
        error = nil
        do {
            issue = try await session.request(api + "/issues/\(number)").json
            comments = try await session.request(api + "/issues/\(number)/comments?per_page=50").json.array.map { ResourceItem($0) }
            if pull { details = try await session.request(api + "/pulls/\(number)").json }
        } catch { self.error = error.localizedDescription }
    }
}

struct DiffView: View {
    let patch: String
    var onLine: ((DiffLine) -> Void)? = nil
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(DiffLine.parse(patch)) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Text(line.oldLine.map(String.init) ?? "").frame(width: 36, alignment: .trailing).foregroundStyle(.secondary)
                        Text(line.newLine.map(String.init) ?? "").frame(width: 36, alignment: .trailing).foregroundStyle(.secondary)
                        Text(line.text).textSelection(.enabled).fixedSize(horizontal: true, vertical: false)
                        if onLine != nil && (line.oldLine != nil || line.newLine != nil) { Button("Comment", systemImage: "bubble.left") { onLine?(line) }.labelStyle(.iconOnly) }
                    }.font(.caption.monospaced()).padding(.vertical, 4).padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(line.kind == .addition ? Color.green.opacity(0.12) : line.kind == .deletion ? Color.red.opacity(0.12) : .clear)
                        .accessibilityLabel("\(line.kind.rawValue), old line \(line.oldLine ?? 0), new line \(line.newLine ?? 0), \(line.text)")
                }
            }
        }.navigationTitle("Diff").overlay { if patch.isEmpty { ContentUnavailableView("Diff unavailable", systemImage: "doc", description: Text("Binary or very large changes may require the browser.")) } }
    }
}

struct PullDiffView: View {
    let repo: String
    let number: Int
    let sha: String
    @Environment(Session.self) private var session
    @State private var files: [ResourceItem] = []
    @State private var error: String?
    @State private var editor: EditorDefinition?
    @State private var next: URL?
    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.red) }
            ForEach(files) { file in
                NavigationLink(file.value["filename"].string) {
                    DiffView(patch: file.value["patch"].string) { line in
                        editor = EditorDefinition(title: "Inline review comment", path: "/repos/\(repo)/pulls/\(number)/comments", fields: [FieldDefinition(key: "body", label: "Comment or suggestion (Markdown)", type: .multiline, required: true)], initial: .object(["commit_id": .string(sha), "path": file.value["filename"], "line": .number(Double(line.newLine ?? line.oldLine ?? 1)), "side": .string(line.newLine == nil ? "LEFT" : "RIGHT")]), help: "For a suggested replacement, wrap the new code in a fenced suggestion block. This publishes an individual inline comment.")
                    }
                }
            }
            if next != nil { Button("Load more files") { Task { await load(more: true) } } }
            Button("Open complete diff in browser") { session.browse("/\(repo)/pull/\(number)/files") }
        }.navigationTitle("Changed files").task { await load() }.sheet(item: $editor) { EditorView(definition: $0) }
    }
    private func load(more: Bool = false) async {
        do { let response = try await session.request(more ? next!.absoluteString : "/repos/\(repo)/pulls/\(number)/files?per_page=100"); let page = response.json.array.map { ResourceItem($0) }; files = more ? files + page : page; next = response.nextURL; error = nil }
        catch { self.error = error.localizedDescription }
    }
}
