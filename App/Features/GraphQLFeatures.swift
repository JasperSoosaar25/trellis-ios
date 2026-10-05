import SwiftUI
import GitHubKit

struct GraphQLCompose: Identifiable {
    let id = UUID()
    let title: String
    let mutation: String
    let fields: [FieldDefinition]
    var initial: [String: JSON] = [:]
}

struct GraphQLComposeView: View {
    let definition: GraphQLCompose
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: String] = [:]
    @State private var error: String?
    @State private var busy = false
    var body: some View {
        NavigationStack {
            Form {
                ForEach(definition.fields) { field in
                    Section(field.label) {
                        if case .multiline = field.type { TextEditor(text: binding(field.key)).frame(minHeight: 120).accessibilityLabel(field.label) }
                        else { TextField(field.label, text: binding(field.key)).textInputAutocapitalization(.never).autocorrectionDisabled() }
                        if !field.help.isEmpty { Text(field.help).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
                if busy { ProgressView("Saving…") }
            }.navigationTitle(definition.title).toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(busy) }
            }.onAppear { values = definition.initial.mapValues(\.string) }
        }.interactiveDismissDisabled(busy)
    }
    private func binding(_ key: String) -> Binding<String> { Binding(get: { values[key] ?? "" }, set: { values[key] = $0 }) }
    private func save() async {
        busy = true; defer { busy = false }
        do {
            var body = definition.initial
            for field in definition.fields {
                let value = values[field.key] ?? ""
                if field.required && value.isEmpty { throw GitHubError.http(422, "\(field.label) is required.") }
                if case .number = field.type { if let number = Double(value) { body[field.key] = .number(number) } }
                else { body[field.key] = .string(value) }
            }
            _ = try await session.graphql(definition.mutation, variables: .object(["input": .object(body)])); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct ProjectsView: View {
    let owner: String
    var organization = false
    @Environment(Session.self) private var session
    @State private var projects: [ResourceItem] = []
    @State private var error: String?
    @State private var cursor: String?
    @State private var more = false
    @State private var compose: GraphQLCompose?
    @State private var ownerID = ""
    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.red); Button("Retry") { Task { await load() } } }
            if projects.isEmpty && error == nil { ContentUnavailableView("No projects", systemImage: "rectangle.3.group") }
            ForEach(projects) { project in NavigationLink { ProjectView(project: project.value) } label: { ResourceRow(value: project.value) } }
            if more { Button("Load more") { Task { await load(next: true) } } }
            Button("Open all projects") { session.browse(organization ? "/orgs/\(owner)/projects" : "/users/\(owner)/projects") }
        }.navigationTitle("Projects")
            .toolbar { if !ownerID.isEmpty { Button("New project", systemImage: "plus") { compose = GraphQLCompose(title: "New project", mutation: "mutation($input:CreateProjectV2Input!){createProjectV2(input:$input){projectV2{id}}}", fields: [FieldDefinition(key: "title", label: "Title", required: true)], initial: ["ownerId": .string(ownerID)]) } } }
            .task { await load() }.refreshable { await load() }.sheet(item: $compose, onDismiss: { Task { await load() } }) { GraphQLComposeView(definition: $0) }
    }
    private func load(next: Bool = false) async {
        do {
            if session.isDemo { projects = []; return }
            let type = organization ? "organization" : "user"
            let result = try await session.graphql("query($owner:String!,$after:String){\(type)(login:$owner){id projectsV2(first:50,after:$after){nodes{id title number shortDescription url closed} pageInfo{hasNextPage endCursor}}}rateLimit{cost remaining resetAt}}", variables: .object(["owner": .string(owner), "after": next ? cursor.map(JSON.string) ?? .null : .null]))
            ownerID = result[type]["id"].string
            let page = result[type]["projectsV2"]; let items = page["nodes"].array.map { ResourceItem($0) }; projects = next ? projects + items : items
            cursor = page.at("pageInfo.endCursor").string; more = page.at("pageInfo.hasNextPage").bool; error = nil
        } catch { self.error = error.localizedDescription }
    }
}

struct ProjectView: View {
    let project: JSON
    @Environment(Session.self) private var session
    @State private var items: [ResourceItem] = []
    @State private var fields: [ResourceItem] = []
    @State private var error: String?
    @State private var compose: GraphQLCompose?
    @State private var selected: ResourceItem?
    @State private var cursor: String?
    @State private var more = false
    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.red); Button("Retry") { Task { await load() } } }
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.value.at("content.title").string.isEmpty ? "Archived or inaccessible item" : item.value.at("content.title").string).font(.headline)
                    ForEach(Array(item.value.at("fieldValues.nodes").array.enumerated()), id: \.offset) { _, value in LabeledContent(value.at("field.name").string, value: value["name"].string.isEmpty ? value["text"].string.isEmpty ? value["number"].string : value["text"].string : value["name"].string) }
                    Button("Edit field") { selected = item }
                    if !item.value.at("content.url").string.isEmpty { Button("Open item") { session.browse(item.value.at("content.url").string) } }
                    Button("Remove from project", role: .destructive) { compose = GraphQLCompose(title: "Remove item", mutation: "mutation($input:DeleteProjectV2ItemInput!){deleteProjectV2Item(input:$input){deletedItemId}}", fields: [], initial: ["projectId": project["id"], "itemId": item.value["id"]]) }
                }
            }
            if items.isEmpty && error == nil { ContentUnavailableView("No project items", systemImage: "rectangle.3.group") }
            if more { Button("Load more") { Task { await load(next: true) } } }
            Button("Add an issue or pull request") { compose = GraphQLCompose(title: "Add existing item", mutation: "mutation($input:AddProjectV2ItemByIdInput!){addProjectV2ItemById(input:$input){item{id}}}", fields: [FieldDefinition(key: "contentId", label: "Issue or PR node ID", required: true, help: "The global node ID is shown in native issue details. The browser also supports searching items.")], initial: ["projectId": project["id"]]) }
            Button("Add draft issue") { compose = GraphQLCompose(title: "Draft issue", mutation: "mutation($input:AddProjectV2DraftIssueInput!){addProjectV2DraftIssue(input:$input){projectItem{id}}}", fields: [FieldDefinition(key: "title", label: "Title", required: true), FieldDefinition(key: "body", label: "Description", type: .multiline)], initial: ["projectId": project["id"]]) }
            Button("Edit project settings") { compose = GraphQLCompose(title: "Project settings", mutation: "mutation($input:UpdateProjectV2Input!){updateProjectV2(input:$input){projectV2{id}}}", fields: [FieldDefinition(key: "title", label: "Title", required: true), FieldDefinition(key: "shortDescription", label: "Description", type: .multiline)], initial: ["projectId": project["id"], "title": project["title"], "shortDescription": project["shortDescription"]]) }
            Button("Open board, views & advanced fields") { session.browse(project["url"].string) }
        }.navigationTitle(project["title"].string).task { await load() }.refreshable { await load() }
            .sheet(item: $compose, onDismiss: { Task { await load() } }) { GraphQLComposeView(definition: $0) }
            .sheet(item: $selected, onDismiss: { Task { await load() } }) { item in ProjectFieldEditor(projectID: project["id"].string, itemID: item.id, fields: fields.map(\.value)) }
    }
    private func load(next: Bool = false) async {
        do {
            let result = try await session.graphql("""
            query($id:ID!,$after:String){node(id:$id){...on ProjectV2{
            fields(first:100){nodes{...on ProjectV2Field{id name dataType} ...on ProjectV2SingleSelectField{id name dataType options{id name}} ...on ProjectV2IterationField{id name dataType}}}
            items(first:50,after:$after){nodes{id type content{...on Issue{title url} ...on PullRequest{title url} ...on DraftIssue{title body}} fieldValues(first:30){nodes{...on ProjectV2ItemFieldTextValue{text field{...on ProjectV2FieldCommon{name}}} ...on ProjectV2ItemFieldNumberValue{number field{...on ProjectV2FieldCommon{name}}} ...on ProjectV2ItemFieldSingleSelectValue{name field{...on ProjectV2FieldCommon{name}}}}}}pageInfo{hasNextPage endCursor}}
            }}rateLimit{cost remaining resetAt}}
            """, variables: .object(["id": project["id"], "after": next ? cursor.map(JSON.string) ?? .null : .null]))
            fields = result.at("node.fields.nodes").array.map { ResourceItem($0) }
            let page = result.at("node.items"); let loaded = page["nodes"].array.map { ResourceItem($0) }; items = next ? items + loaded : loaded
            cursor = page.at("pageInfo.endCursor").string; more = page.at("pageInfo.hasNextPage").bool; error = nil
        } catch { self.error = error.localizedDescription }
    }
}

struct ProjectFieldEditor: View {
    let projectID: String
    let itemID: String
    let fields: [JSON]
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var fieldID = ""
    @State private var value = ""
    @State private var error: String?
    var supported: [JSON] { fields.filter { ["TEXT", "NUMBER", "DATE", "SINGLE_SELECT"].contains($0["dataType"].string) } }
    var field: JSON { supported.first { $0["id"].string == fieldID } ?? .null }
    var body: some View {
        NavigationStack {
            Form {
                Picker("Field", selection: $fieldID) { ForEach(supported.map { ResourceItem($0) }) { Text($0.value["name"].string).tag($0.id) } }
                if field["dataType"].string == "SINGLE_SELECT" { Picker("Value", selection: $value) { Text("Choose…").tag(""); ForEach(field["options"].array.map { ResourceItem($0) }) { Text($0.value["name"].string).tag($0.id) } } }
                else { TextField(field["dataType"].string == "DATE" ? "YYYY-MM-DD" : "Value", text: $value) }
                if let error { Text(error).foregroundStyle(.red) }
                Button("Save field") { Task { await save() } }.disabled(fieldID.isEmpty || value.isEmpty)
            }.navigationTitle("Project field").toolbar { Button("Cancel") { dismiss() } }.onAppear { fieldID = supported.first?["id"].string ?? "" }.onChange(of: fieldID) { _, _ in value = "" }
        }
    }
    private func save() async {
        do {
            let type = field["dataType"].string
            let key = ["TEXT": "text", "NUMBER": "number", "DATE": "date", "SINGLE_SELECT": "singleSelectOptionId"][type] ?? "text"
            let payload: JSON
            if type == "NUMBER" { guard let number = Double(value) else { throw GitHubError.http(422, "Enter a number.") }; payload = .number(number) } else { payload = .string(value) }
            _ = try await session.graphql("mutation($input:UpdateProjectV2ItemFieldValueInput!){updateProjectV2ItemFieldValue(input:$input){projectV2Item{id}}}", variables: .object(["input": .object(["projectId": .string(projectID), "itemId": .string(itemID), "fieldId": .string(fieldID), "value": .object([key: payload])])]))
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct DiscussionsView: View {
    let repo: String
    @Environment(Session.self) private var session
    @State private var discussions: [ResourceItem] = []
    @State private var categories: [ResourceItem] = []
    @State private var error: String?
    @State private var compose: GraphQLCompose?
    @State private var repositoryID = ""
    @State private var cursor: String?
    @State private var more = false
    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.red); Button("Retry") { Task { await load() } } }
            ForEach(discussions) { discussion in NavigationLink { DiscussionView(repo: repo, discussion: discussion.value) } label: { ResourceRow(value: discussion.value) } }
            if discussions.isEmpty && error == nil { ContentUnavailableView("No discussions", systemImage: "bubble.left.and.bubble.right") }
            if more { Button("Load more") { Task { await load(next: true) } } }
            Section("Categories") { ForEach(categories) { category in LabeledContent(category.value["name"].string, value: category.id).font(.caption).textSelection(.enabled) } }
            Button("Open discussions on GitHub") { session.browse("/\(repo)/discussions") }
        }.navigationTitle("Discussions").toolbar { if !repositoryID.isEmpty { Button("New discussion", systemImage: "plus") { compose = GraphQLCompose(title: "New discussion", mutation: "mutation($input:CreateDiscussionInput!){createDiscussion(input:$input){discussion{id}}}", fields: [FieldDefinition(key: "title", label: "Title", required: true), FieldDefinition(key: "body", label: "Body (Markdown)", type: .multiline, required: true), FieldDefinition(key: "categoryId", label: "Category ID", required: true)], initial: ["repositoryId": .string(repositoryID), "categoryId": categories.first?.value["id"] ?? .null]) } } }
            .task { await load() }.refreshable { await load() }.sheet(item: $compose, onDismiss: { Task { await load() } }) { GraphQLComposeView(definition: $0) }
    }
    private func load(next: Bool = false) async {
        guard repo.split(separator: "/").count == 2 else { return }
        do {
            let parts = repo.split(separator: "/")
            let result = try await session.graphql("query($owner:String!,$name:String!,$after:String){repository(owner:$owner,name:$name){id discussionCategories(first:100){nodes{id name}} discussions(first:50,after:$after,orderBy:{field:UPDATED_AT,direction:DESC}){nodes{id number title body url author{login}} pageInfo{hasNextPage endCursor}}}rateLimit{cost remaining resetAt}}", variables: .object(["owner": .string(String(parts[0])), "name": .string(String(parts[1])), "after": next ? cursor.map(JSON.string) ?? .null : .null]))
            repositoryID = result.at("repository.id").string; categories = result.at("repository.discussionCategories.nodes").array.map { ResourceItem($0) }
            let page = result.at("repository.discussions"); let loaded = page["nodes"].array.map { ResourceItem($0) }; discussions = next ? discussions + loaded : loaded; cursor = page.at("pageInfo.endCursor").string; more = page.at("pageInfo.hasNextPage").bool; error = nil
        } catch { self.error = error.localizedDescription }
    }
}

struct DiscussionView: View {
    let repo: String
    let discussion: JSON
    @Environment(Session.self) private var session
    @State private var comments: [ResourceItem] = []
    @State private var error: String?
    @State private var compose: GraphQLCompose?
    var body: some View {
        List {
            Section { ResourceRow(value: discussion); MarkdownView(text: discussion["body"].string) }
            if let error { Text(error).foregroundStyle(.red) }
            Section("Comments") { ForEach(comments) { comment in VStack(alignment: .leading) { Text(comment.value.at("author.login").string).font(.headline); MarkdownView(text: comment.value["body"].string) } } }
            Button("Reply") { compose = GraphQLCompose(title: "Reply to discussion", mutation: "mutation($input:AddDiscussionCommentInput!){addDiscussionComment(input:$input){comment{id}}}", fields: [FieldDefinition(key: "body", label: "Comment (Markdown)", type: .multiline, required: true)], initial: ["discussionId": discussion["id"]]) }
            Button("Open full discussion") { session.browse(discussion["url"].string) }
        }.navigationTitle("Discussion #\(discussion["number"].int)").task { await load() }.sheet(item: $compose, onDismiss: { Task { await load() } }) { GraphQLComposeView(definition: $0) }
    }
    private func load() async {
        do { let result = try await session.graphql("query($id:ID!){node(id:$id){...on Discussion{comments(first:100){nodes{id body author{login}}}}}rateLimit{cost remaining resetAt}}", variables: .object(["id": discussion["id"]])); comments = result.at("node.comments.nodes").array.map { ResourceItem($0) }; error = nil }
        catch { self.error = error.localizedDescription }
    }
}
