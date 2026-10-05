import SwiftUI
import GitHubKit

struct RepositoryIssuesView: View {
    let repo: String
    var pulls = false
    @State private var state = "open"
    @State private var labels = ""
    @State private var assignee = ""
    @State private var milestone = ""
    @State private var sort = "updated"
    var body: some View {
        VStack(spacing: 0) {
            DisclosureGroup("Filters") {
                VStack {
                    Picker("State", selection: $state) { Text("Open").tag("open"); Text("Closed").tag("closed"); Text("All").tag("all") }.pickerStyle(.segmented)
                    TextField("Labels, comma-separated", text: $labels).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Assignee username", text: $assignee).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Milestone number", text: $milestone)
                    Picker("Sort", selection: $sort) { Text("Updated").tag("updated"); Text("Created").tag("created"); Text("Comments").tag("comments") }
                }.textFieldStyle(.roundedBorder)
            }.padding()
            ResourceList(title: pulls ? "Pull requests" : "Issues", path: path, key: "items", kind: pulls ? .pull(repo) : .issue(repo), webPath: "/\(repo)/\(pulls ? "pulls" : "issues")", editor: pulls ? .pull(repo, branch: "main") : .issue(repo))
        }
    }
    private var path: String {
        var query = "repo:\(repo) is:\(pulls ? "pr" : "issue")"
        if state != "all" { query += " is:\(state)" }
        if !assignee.isEmpty { query += " assignee:\(assignee)" }
        if !milestone.isEmpty { query += " milestone:\(milestone)" }
        for label in labels.split(separator: ",") { query += " label:\"\(label.trimmingCharacters(in: .whitespaces))\"" }
        return "/search/issues?" + URLCoding.query(["q": query, "sort": sort, "per_page": "50"])
    }
}

struct CommentView: View {
    let comment: JSON
    let root: String
    @Environment(Session.self) private var session
    @State private var editor: EditorDefinition?
    @State private var message: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(comment.at("user.login").string).font(.headline); Spacer(); menu }
            MarkdownView(text: comment["body"].string)
            if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
        }.sheet(item: $editor) { EditorView(definition: $0) }
    }
    private var menu: some View {
        Menu {
            Menu("React") {
                ForEach(["+1", "-1", "laugh", "confused", "heart", "hooray", "rocket", "eyes"], id: \.self) { reaction in
                    Button(reaction) { Task { do { _ = try await session.request(root + "/reactions", method: "POST", body: .object(["content": .string(reaction)])); message = "Reaction added." } catch { message = error.localizedDescription } } }
                }
            }
            if comment.at("user.login").string == session.login {
                Button("Edit comment") { editor = EditorDefinition(title: "Edit comment", path: root, method: "PATCH", fields: [FieldDefinition(key: "body", label: "Comment (Markdown)", type: .multiline, required: true)], initial: .object(["body": comment["body"]])) }
                // This nested ActionMenu retains its own concrete confirmation.
                ActionMenu(title: "Delete comment", actions: [APIAction(title: "Delete your comment", path: root, method: "DELETE", destructive: true)], onSuccess: { message = "Comment deleted. Refresh to update the conversation." })
            }
        } label: { Image(systemName: "ellipsis").accessibilityLabel("Comment actions") }
    }
}

struct SubIssuesView: View {
    let repo: String
    let parent: Int
    @Environment(Session.self) private var session
    @State private var number = ""
    @State private var message: String?
    var body: some View {
        VStack {
            ResourceList(title: "Sub-issues", path: "/repos/\(repo)/issues/\(parent)/sub_issues?per_page=100", kind: .issue(repo), webPath: "/\(repo)/issues/\(parent)")
            Form {
                TextField("Existing issue number in this repository", text: $number).keyboardType(.numberPad)
                Button("Add sub-issue") { Task { await add() } }.disabled(Int(number) == nil)
                if let message { Text(message).font(.caption) }
            }.frame(maxHeight: 180)
        }
    }
    private func add() async {
        do {
            let issue = try await session.request("/repos/\(repo)/issues/\(number)", cache: false).json
            _ = try await session.request("/repos/\(repo)/issues/\(parent)/sub_issues", method: "POST", body: .object(["sub_issue_id": issue["id"]])); message = "Sub-issue added. Pull to refresh the list."; number = ""
        } catch { message = error.localizedDescription }
    }
}
