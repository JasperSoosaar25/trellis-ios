import SwiftUI
import GitHubKit

enum FieldType { case text, multiline, secure, number, toggle, choice([String]), csv, json }
struct FieldDefinition: Identifiable {
    var id: String { key }
    let key: String
    let label: String
    var type: FieldType = .text
    var required = false
    var help = ""
}
struct EditorDefinition: Identifiable {
    let id = UUID()
    let title: String
    let path: String
    var method = "POST"
    let fields: [FieldDefinition]
    var initial: JSON = .object([:])
    var help = ""
    var transform: ((JSON) throws -> JSON)? = nil
}

struct EditorView: View {
    let definition: EditorDefinition
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: String]
    @State private var busy = false
    @State private var error: String?
    init(definition: EditorDefinition) {
        self.definition = definition
        var values: [String: String] = [:]
        for field in definition.fields {
            let value = definition.initial[field.key]
            switch field.type {
            case .csv: values[field.key] = value.array.map(\.string).joined(separator: ", ")
            case .json: values[field.key] = value.isNull ? "" : String(decoding: (try? value.encoded(pretty: true)) ?? Data(), as: UTF8.self)
            case .toggle: values[field.key] = value.bool ? "true" : "false"
            case .choice(let options): values[field.key] = value.string.isEmpty ? options.first : value.string
            default: values[field.key] = value.string
            }
        }
        _values = State(initialValue: values)
    }
    var body: some View {
        NavigationStack {
            Form {
                if !definition.help.isEmpty { Section { Text(definition.help).font(.footnote).foregroundStyle(.secondary) } }
                ForEach(definition.fields) { field in
                    Section {
                        control(field)
                    } header: { Text(field.label + (field.required ? " *" : "")) } footer: { if !field.help.isEmpty { Text(field.help) } }
                }
                if let error { Section { Text(error).foregroundStyle(.red).textSelection(.enabled) } }
                if busy { ProgressView("Saving…") }
            }.navigationTitle(definition.title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(busy) }
                }
        }.interactiveDismissDisabled(busy)
    }
    private func binding(_ key: String) -> Binding<String> { Binding(get: { values[key] ?? "" }, set: { values[key] = $0 }) }
    @ViewBuilder private func control(_ field: FieldDefinition) -> some View {
        switch field.type {
        case .multiline, .json: TextEditor(text: binding(field.key)).frame(minHeight: 120).font(field.type.isJSON ? .body.monospaced() : .body).accessibilityLabel(field.label)
        case .secure: SecureField(field.label, text: binding(field.key)).textInputAutocapitalization(.never).autocorrectionDisabled()
        case .toggle: Toggle(field.label, isOn: Binding(get: { values[field.key] == "true" }, set: { values[field.key] = $0 ? "true" : "false" }))
        case .choice(let options): Picker(field.label, selection: binding(field.key)) { ForEach(options, id: \.self) { Text($0).tag($0) } }
        default: TextField(field.label, text: binding(field.key)).textInputAutocapitalization(.never).autocorrectionDisabled()
        }
    }
    private func save() async {
        busy = true; error = nil; defer { busy = false }
        do {
            var object = definition.initial.object
            for field in definition.fields {
                let value = values[field.key] ?? ""
                if field.required && value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw GitHubError.http(422, "\(field.label) is required.") }
                switch field.type {
                case .toggle: object[field.key] = .bool(value == "true")
                case .number:
                    if !value.isEmpty { guard let number = Double(value), number.isFinite else { throw GitHubError.http(422, "\(field.label) must be a number.") }; object[field.key] = .number(number) }
                case .csv: object[field.key] = .array(value.split(separator: ",").map { .string($0.trimmingCharacters(in: .whitespaces)) })
                case .json:
                    if !value.isEmpty { object[field.key] = try JSON.decode(Data(value.utf8)) }
                default:
                    if !value.isEmpty || !definition.initial[field.key].isNull { object[field.key] = .string(value) }
                }
            }
            let body = try definition.transform?(.object(object)) ?? .object(object)
            var path = definition.path
            for (key, value) in object { path = path.replacingOccurrences(of: "{\(key)}", with: key == "path" ? URLCoding.path(value.string) : URLCoding.segment(value.string)) }
            _ = try await session.request(path, method: definition.method, body: body)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
private extension FieldType { var isJSON: Bool { if case .json = self { return true }; return false } }

struct APIAction: Identifiable {
    let id = UUID()
    let title: String
    let path: String
    var method = "POST"
    var body: JSON? = nil
    var destructive = false
}

struct ActionMenu: View {
    let title: String
    let actions: [APIAction]
    var onSuccess: () -> Void = {}
    @Environment(Session.self) private var session
    @State private var selection: APIAction?
    @State private var result: String?
    @State private var busy = false
    var body: some View {
        Menu {
            ForEach(actions) { action in Button(action.title, role: action.destructive ? .destructive : nil) { selection = action } }
        } label: { Label(title, systemImage: "ellipsis.circle") }.disabled(busy)
        .confirmationDialog(selection?.title ?? "Confirm action", isPresented: Binding(get: { selection != nil }, set: { if !$0 { selection = nil } }), titleVisibility: .visible) {
            if let action = selection { Button(action.title, role: action.destructive ? .destructive : nil) { Task { await perform(action) } } }
            Button("Cancel", role: .cancel) { selection = nil }
        } message: { Text("This changes the selected resource on GitHub.") }
        .alert("Result", isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } })) { Button("OK") { result = nil } } message: { Text(result ?? "") }
    }
    private func perform(_ action: APIAction) async {
        busy = true; selection = nil; defer { busy = false }
        do {
            let response = try await session.request(action.path, method: action.method, body: action.body, cache: false)
            if !response.json["token"].string.isEmpty { result = "Registration token (expires \(response.json["expires_at"].string)):\n\(response.json["token"].string)" }
            else { result = "\(action.title) completed." }
            onSuccess()
        } catch { result = error.localizedDescription }
    }
}
