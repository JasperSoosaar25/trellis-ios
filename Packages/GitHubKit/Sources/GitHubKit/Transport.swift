import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HTTPResponse: Sendable {
    public let data: Data
    public let status: Int
    public let headers: [String: String]
    public init(data: Data, status: Int, headers: [String: String] = [:]) {
        self.data = data; self.status = status
        self.headers = Dictionary(headers.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { _, b in b })
    }
}

public struct HTTPTransport: Sendable {
    public let send: @Sendable (URLRequest) async throws -> HTTPResponse
    public init(send: @escaping @Sendable (URLRequest) async throws -> HTTPResponse) { self.send = send }
    public static let live = HTTPTransport { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GitHubError.malformedResponse }
        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields { headers[String(describing: key)] = String(describing: value) }
        return HTTPResponse(data: data, status: http.statusCode, headers: headers)
    }
}

public struct APIResponse: Sendable {
    public let data: Data
    public let headers: [String: String]
    public let status: Int
    public let isOffline: Bool
    public var json: JSON { (try? JSON.decode(data)) ?? .null }
    public var nextURL: URL? { Pagination.next(in: headers["link"]) }
}

public enum Pagination {
    public static func next(in link: String?) -> URL? {
        guard let link else { return nil }
        for part in link.split(separator: ",") {
            let fields = part.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            guard fields.count > 1, fields.dropFirst().contains(where: { $0 == "rel=\"next\"" }),
                  let first = fields.first, first.hasPrefix("<"), first.hasSuffix(">") else { continue }
            return URL(string: String(first.dropFirst().dropLast()))
        }
        return nil
    }
}

public enum URLCoding {
    public static func segment(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~"))) ?? ""
    }
    public static func path(_ value: String) -> String { value.split(separator: "/", omittingEmptySubsequences: false).map { segment(String($0)) }.joined(separator: "/") }
    public static func query(_ items: [String: String]) -> String {
        var c = URLComponents(); c.queryItems = items.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return c.percentEncodedQuery ?? ""
    }
}
