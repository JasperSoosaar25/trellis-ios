import SwiftUI
import Observation
import GitHubKit

@MainActor @Observable final class Session {
    var client: GitHubClient?
    var profile: JSON = .null
    var grantedScopes: Set<String>?
    var requestedScopes = AuthScopes.basic
    var tab = 0
    var isDemo = false
    var restoring = false
    var error: String?
    var webRoute: WebRoute?
    var unreadCount = 0
    var pollInterval: TimeInterval = 60
    var contributions: JSON = .null

    init() {
        if ProcessInfo.processInfo.arguments.contains("--demo") {
            isDemo = true; profile = Demo.profile; contributions = Demo.contributions
        } else if let token = Keychain.read() {
            client = GitHubClient(token: token); restoring = true
            Task { await restore(token) }
        }
    }
    var signedIn: Bool { isDemo || !profile.isNull }
    var login: String { profile["login"].string }
    func authenticate(_ raw: String) async throws {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw GitHubError.unauthorized }
        let candidate = GitHubClient(token: token)
        let result = try await candidate.request("/user", useCache: false)
        guard !result.json["login"].string.isEmpty else { throw GitHubError.malformedResponse }
        try Keychain.write(token)
        profile = result.json; grantedScopes = await candidate.scopes
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("TrellisAPI")
        let directory = base.appendingPathComponent(URLCoding.segment(login))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var excluded = directory; var values = URLResourceValues(); values.isExcludedFromBackup = true; try? excluded.setResourceValues(values)
        client = GitHubClient(token: token, cacheDirectory: directory); isDemo = false; error = nil
        BackgroundRefresh.schedule()
        Task { await loadContributions() }
    }
    private func restore(_ token: String) async {
        defer { restoring = false }
        do { try await authenticate(token) }
        catch { self.error = error.localizedDescription; client = nil }
    }
    func logout() async {
        await client?.clearCache(); Keychain.delete(); client = nil; profile = .null
        isDemo = false; contributions = .null; grantedScopes = nil; unreadCount = 0
        BackgroundRefresh.cancel()
    }
    func request(_ path: String, method: String = "GET", body: JSON? = nil, accept: String = "application/vnd.github+json", cache: Bool = true) async throws -> APIResponse {
        if isDemo {
            guard method == "GET" else { throw GitHubError.http(403, "Demo mode is read-only. Sign in to make changes.") }
            return APIResponse.demo(Demo.resource(path))
        }
        guard let client else { throw GitHubError.unauthorized }
        let response = try await client.request(path, method: method, body: body, accept: accept, useCache: cache)
        grantedScopes = await client.scopes ?? grantedScopes; pollInterval = await client.pollInterval
        return response
    }
    func graphql(_ query: String, variables: JSON = .object([:])) async throws -> JSON {
        if isDemo { return .object([:]) }
        guard let client else { throw GitHubError.unauthorized }
        return try await client.graphql(query, variables: variables)
    }
    func browse(_ path: String) { webRoute = WebRoute(path: path) }
    func loadContributions() async {
        guard !isDemo else { return }
        do {
            let data = try await graphql("query { viewer { contributionsCollection { contributionCalendar { totalContributions weeks { contributionDays { date contributionCount color } } } } } rateLimit { cost remaining resetAt } }")
            contributions = data.at("viewer.contributionsCollection.contributionCalendar")
        } catch { /* Profile remains usable; the contribution view exposes retry. */ }
    }
}

struct WebRoute: Identifiable {
    let id = UUID()
    let url: URL
    init(path: String) { url = URL(string: path.hasPrefix("https://") ? path : "https://github.com" + path)! }
}
