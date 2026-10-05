import Foundation

/// Lossless structural JSON shared by heterogeneous API resources.
public enum JSON: Codable, Sendable, Equatable, Hashable {
    case object([String: JSON]), array([JSON]), string(String), number(Double), bool(Bool), null

    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let x = try? c.decode(Bool.self) { self = .bool(x) }
        else if let x = try? c.decode(Double.self) { self = .number(x) }
        else if let x = try? c.decode(String.self) { self = .string(x) }
        else if let x = try? c.decode([JSON].self) { self = .array(x) }
        else { self = .object(try c.decode([String: JSON].self)) }
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let x): try c.encode(x)
        case .array(let x): try c.encode(x)
        case .string(let x): try c.encode(x)
        case .number(let x): try c.encode(x)
        case .bool(let x): try c.encode(x)
        case .null: try c.encodeNil()
        }
    }
    public subscript(_ key: String) -> JSON { if case .object(let x) = self { return x[key] ?? .null }; return .null }
    public subscript(_ index: Int) -> JSON { array.indices.contains(index) ? array[index] : .null }
    public var array: [JSON] { if case .array(let x) = self { return x }; return [] }
    public var object: [String: JSON] { if case .object(let x) = self { return x }; return [:] }
    public var string: String {
        switch self {
        case .string(let x): return x
        case .number(let x): return x.rounded() == x ? String(format: "%.0f", x) : String(x)
        case .bool(let x): return String(x)
        default: return ""
        }
    }
    public var int: Int { if case .number(let x) = self { return Int(x) }; return Int(string) ?? 0 }
    public var bool: Bool { if case .bool(let x) = self { return x }; return false }
    public var isNull: Bool { self == .null }
    public func at(_ path: String) -> JSON { path.split(separator: ".").reduce(self) { $0[String($1)] } }
    public func encoded(pretty: Bool = false) throws -> Data {
        let encoder = JSONEncoder(); if pretty { encoder.outputFormatting = [.prettyPrinted, .sortedKeys] }
        return try encoder.encode(self)
    }
    public static func decode(_ data: Data) throws -> JSON { try JSONDecoder().decode(JSON.self, from: data) }
    public static func text(_ x: String) -> JSON { .string(x) }
}

public struct ResourceItem: Identifiable, Sendable, Hashable {
    public let value: JSON
    public let id: String
    public init(_ value: JSON, fallback: String = UUID().uuidString) {
        self.value = value
        id = [value["id"].string, value["node_id"].string, value["name"].string, value["sha"].string, value["path"].string]
            .first { !$0.isEmpty } ?? fallback
    }
}

public enum GitHubError: Error, Sendable, LocalizedError, Equatable {
    case invalidURL, malformedResponse, unauthorized, forbidden(String), notFound
    case rateLimited(Date), http(Int, String), graphql(String), deviceFlow(String), oversized
    public var errorDescription: String? {
        switch self {
        case .invalidURL: "This address cannot be requested securely."
        case .malformedResponse: "The server returned an unexpected response."
        case .unauthorized: "Your token is invalid or expired. Sign in again."
        case .forbidden(let message): "Access denied. Check token permissions, your repository role, organization OAuth approval and SSO authorization. \(message)"
        case .notFound: "This resource does not exist or your account cannot access it."
        case .rateLimited(let date): "API limit reached. Try again after \(date.formatted())."
        case .http(let code, let message): "Request failed (\(code)): \(message)"
        case .graphql(let message): "\(message)"
        case .deviceFlow(let message): "\(message)"
        case .oversized: "This file is too large for the mobile viewer. Open it in the browser."
        }
    }
}
