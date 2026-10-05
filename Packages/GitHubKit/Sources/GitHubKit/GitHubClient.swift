import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private struct CacheEntry: Codable, Sendable {
    let data: Data
    let headers: [String: String]
    let saved: Date
}

public struct RateLimit: Sendable, Equatable {
    public var remaining: Int?
    public var reset: Date?
    public var graphqlCost: Int?
    public init() {}
}

public actor GitHubClient {
    private let token: String
    private let transport: HTTPTransport
    private let cacheDirectory: URL?
    private var cache: [String: CacheEntry] = [:]
    public private(set) var rateLimit = RateLimit()
    public private(set) var scopes: Set<String>?
    public private(set) var pollInterval: TimeInterval = 60
    private let maxBytes = 16 * 1024 * 1024

    public init(token: String, transport: HTTPTransport = .live, cacheDirectory: URL? = nil) {
        self.token = token; self.transport = transport; self.cacheDirectory = cacheDirectory
        if let cacheDirectory { try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true) }
    }

    public func request(_ path: String, method: String = "GET", body: JSON? = nil,
                        accept: String = "application/vnd.github+json", useCache: Bool = true) async throws -> APIResponse {
        let url: URL?
        if path.hasPrefix("https://") { url = URL(string: path) }
        else { url = URL(string: "https://api.github.com" + (path.hasPrefix("/") ? path : "/" + path)) }
        guard let url, url.scheme == "https", ["api.github.com", "uploads.github.com"].contains(url.host ?? ""), url.user == nil, url.password == nil else { throw GitHubError.invalidURL }
        let key = url.absoluteString + "|" + accept
        let previous = useCache && method == "GET" ? readCache(key) : nil
        var request = URLRequest(url: url); request.httpMethod = method; request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Trellis/1.0", forHTTPHeaderField: "User-Agent")
        if let body { request.httpBody = try body.encoded(); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let previous {
            if let etag = previous.headers["etag"] { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
            if let modified = previous.headers["last-modified"] { request.setValue(modified, forHTTPHeaderField: "If-Modified-Since") }
        }
        var response: HTTPResponse
        do {
            response = try await transport.send(request)
            // Retry only safe reads, only briefly. Long primary-limit resets belong in UI.
            if method == "GET" {
                for attempt in 0..<2 {
                    let limited = response.status == 429 || (response.status == 403 && (response.headers["retry-after"] != nil || response.headers["x-ratelimit-remaining"] == "0"))
                    guard limited, let retry = Double(response.headers["retry-after"] ?? ""), retry > 0, retry <= 3 else { break }
                    try await Task.sleep(for: .seconds(retry * Double(attempt + 1)))
                    response = try await transport.send(request)
                }
            }
        } catch {
            if !Task.isCancelled, let previous, let network = error as? URLError,
               [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost].contains(network.code) {
                return APIResponse(data: previous.data, headers: previous.headers, status: 200, isOffline: true)
            }
            throw error
        }
        updateMetadata(response.headers)
        if response.status == 304, let previous {
            let merged = previous.headers.merging(response.headers) { _, b in b }
            saveCache(CacheEntry(data: previous.data, headers: merged, saved: Date()), key: key)
            return APIResponse(data: previous.data, headers: merged, status: 304, isOffline: false)
        }
        guard (200..<300).contains(response.status) else { throw failure(response) }
        guard response.data.count <= maxBytes else { throw GitHubError.oversized }
        if useCache && method == "GET" { saveCache(CacheEntry(data: response.data, headers: response.headers, saved: Date()), key: key) }
        else if method != "GET" { clearCache() }
        return APIResponse(data: response.data, headers: response.headers, status: response.status, isOffline: false)
    }

    public func graphql(_ query: String, variables: JSON = .object([:])) async throws -> JSON {
        let response = try await request("/graphql", method: "POST", body: .object(["query": .string(query), "variables": variables]))
        let root = try JSON.decode(response.data)
        let rate = root.at("data.rateLimit")
        if !rate.isNull {
            rateLimit.remaining = rate["remaining"].int; rateLimit.graphqlCost = rate["cost"].int
            rateLimit.reset = ISO8601DateFormatter().date(from: rate["resetAt"].string)
        }
        if !root["errors"].array.isEmpty { throw GitHubError.graphql(root["errors"].array.map { $0["message"].string }.joined(separator: "\n")) }
        guard !root["data"].isNull else { throw GitHubError.malformedResponse }
        return root["data"]
    }

    public func clearCache() {
        cache.removeAll()
        if let directory = cacheDirectory, let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" { try? FileManager.default.removeItem(at: file) }
        }
    }
    private func updateMetadata(_ headers: [String: String]) {
        if let raw = headers["x-oauth-scopes"] { scopes = Set(raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }) }
        if let raw = headers["x-ratelimit-remaining"] { rateLimit.remaining = Int(raw) }
        if let raw = headers["x-ratelimit-reset"], let time = Double(raw) { rateLimit.reset = Date(timeIntervalSince1970: time) }
        if let raw = headers["x-poll-interval"], let time = Double(raw) { pollInterval = max(60, time) }
    }
    private func failure(_ r: HTTPResponse) -> GitHubError {
        let json = (try? JSON.decode(r.data)) ?? .null
        let message = json["message"].string.isEmpty ? "The server refused this operation." : json["message"].string
        if r.status == 429 || (r.status == 403 && (r.headers["x-ratelimit-remaining"] == "0" || r.headers["retry-after"] != nil)) {
            let reset = r.headers["retry-after"].flatMap(Double.init).map { Date().addingTimeInterval($0) } ?? rateLimit.reset ?? Date().addingTimeInterval(60)
            return .rateLimited(reset)
        }
        switch r.status {
        case 401: return .unauthorized
        case 403: return .forbidden(message)
        case 404: return .notFound
        default: return .http(r.status, message)
        }
    }
    private func fileURL(_ key: String) -> URL? {
        var hash: UInt64 = 14695981039346656037
        for byte in key.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return cacheDirectory?.appendingPathComponent(String(hash, radix: 16) + ".json")
    }
    private func readCache(_ key: String) -> CacheEntry? {
        if let entry = cache[key] { return entry }
        guard let url = fileURL(key), let data = try? Data(contentsOf: url), let entry = try? JSONDecoder().decode(CacheEntry.self, from: data), Date().timeIntervalSince(entry.saved) < 7 * 86400 else { return nil }
        cache[key] = entry; return entry
    }
    private func saveCache(_ entry: CacheEntry, key: String) {
        if cache.count >= 60 || cache.values.reduce(0, { $0 + $1.data.count }) + entry.data.count > 32 * 1024 * 1024 { cache.removeAll() }
        cache[key] = entry
        guard entry.data.count <= 2 * 1024 * 1024, let url = fileURL(key), let encoded = try? JSONEncoder().encode(entry) else { return }
        try? encoded.write(to: url, options: .atomic)
        if let directory = cacheDirectory, let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) {
            let sorted = files.sorted { ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) < ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
            var size = sorted.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
            for file in sorted where size > 32 * 1024 * 1024 { size -= (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0; try? FileManager.default.removeItem(at: file) }
        }
    }
}
