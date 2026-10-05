import Foundation

public struct WorkflowInput: Sendable, Identifiable, Equatable {
    public let id: String
    public var description: String = ""
    public var type: String = "string"
    public var required = false
    public var defaultValue = ""
    public var options: [String] = []
    public init(id: String) { self.id = id }
}

public struct WorkflowDefinition: Sendable, Equatable {
    public var inputs: [WorkflowInput]
    public var supportsDispatch: Bool
    public var needsAdvancedEditor: Bool

    /// Handles the conventional block YAML used by workflow_dispatch. Complex YAML
    /// (anchors, flow mappings and multiline defaults) is explicitly reported.
    public static func parse(_ source: String) -> WorkflowDefinition {
        var inputs: [WorkflowInput] = []; var dispatchIndent: Int?; var inputsIndent: Int?
        var inputIndent: Int?; var current: WorkflowInput?; var inOptions = false
        var supported = false; var advanced = false
        func unquote(_ x: String) -> String {
            let text = x.trimmingCharacters(in: .whitespaces)
            if text.count >= 2, (text.hasPrefix("\"") && text.hasSuffix("\"")) || (text.hasPrefix("'") && text.hasSuffix("'")) { return String(text.dropFirst().dropLast()) }
            return text
        }
        for raw in source.components(separatedBy: .newlines) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let indent = raw.prefix { $0 == " " }.count
            if trimmed.hasPrefix("workflow_dispatch:") {
                supported = true; dispatchIndent = indent
                if trimmed != "workflow_dispatch:" && trimmed != "workflow_dispatch: {}" { advanced = true }
                continue
            }
            guard let dispatch = dispatchIndent else { continue }
            if indent <= dispatch {
                if let current { inputs.append(current) }
                current = nil; dispatchIndent = nil; inputsIndent = nil; inputIndent = nil
                continue
            }
            if trimmed == "inputs:" { inputsIndent = indent; continue }
            guard let parent = inputsIndent, indent > parent else { continue }
            if trimmed.contains("&") || trimmed.hasPrefix("<<:") { advanced = true }
            if inOptions && trimmed.hasPrefix("- ") { current?.options.append(unquote(String(trimmed.dropFirst(2)))); continue }
            guard let colon = trimmed.firstIndex(of: ":") else { advanced = true; continue }
            let key = unquote(String(trimmed[..<colon])); let value = unquote(String(trimmed[trimmed.index(after: colon)...]))
            if inputIndent == nil || indent == inputIndent {
                if let current { inputs.append(current) }
                current = WorkflowInput(id: key); inputIndent = indent; inOptions = false
                if !value.isEmpty { advanced = true }
                continue
            }
            inOptions = false
            switch key {
            case "description": current?.description = value
            case "type": current?.type = value
            case "required": current?.required = value == "true"
            case "default": current?.defaultValue = value
            case "options":
                inOptions = true
                if value.hasPrefix("[") && value.hasSuffix("]") { current?.options = value.dropFirst().dropLast().split(separator: ",").map { unquote(String($0)) } }
                else if !value.isEmpty { advanced = true }
            default: advanced = true
            }
            if ["|", ">", "|-", ">-"].contains(value) || value.contains("${{") || value.contains("\\") { advanced = true }
        }
        if let current { inputs.append(current) }
        return WorkflowDefinition(inputs: inputs, supportsDispatch: supported, needsAdvancedEditor: advanced)
    }
    public func values(_ values: [String: String]) throws -> JSON {
        var result: [String: JSON] = [:]
        for input in inputs {
            let value = values[input.id] ?? input.defaultValue
            if input.required && value.isEmpty { throw GitHubError.http(422, "\(input.id) is required.") }
            if value.isEmpty { continue }
            switch input.type {
            case "boolean":
                guard ["true", "false"].contains(value) else { throw GitHubError.http(422, "\(input.id) must be true or false.") }
                result[input.id] = .bool(value == "true")
            case "number":
                guard let number = Double(value), number.isFinite else { throw GitHubError.http(422, "\(input.id) must be a number.") }
                result[input.id] = .number(number)
            case "choice":
                guard input.options.contains(value) else { throw GitHubError.http(422, "Choose an option for \(input.id).") }
                result[input.id] = .string(value)
            default: result[input.id] = .string(value)
            }
        }
        return .object(result)
    }
}
