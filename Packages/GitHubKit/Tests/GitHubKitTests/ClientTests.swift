import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import GitHubKit

actor Stub {
    var responses: [HTTPResponse]
    var requests: [URLRequest] = []
    var offline = false
    init(_ responses: [HTTPResponse]) { self.responses = responses }
    func send(_ request: URLRequest) throws -> HTTPResponse {
        requests.append(request)
        if offline { throw URLError(.notConnectedToInternet) }
        guard !responses.isEmpty else { throw GitHubError.malformedResponse }
        return responses.removeFirst()
    }
    func setOffline() { offline = true }
    var transport: HTTPTransport { HTTPTransport { request in try await self.send(request) } }
}

func response(_ source: String, status: Int = 200, headers: [String: String] = [:]) -> HTTPResponse { HTTPResponse(data: Data(source.utf8), status: status, headers: headers) }

@Test func conditionalRequestsPreserveBodyAndPagination() async throws {
    let stub = Stub([response("[{\"id\":1}]", headers: ["ETag": "tag", "Last-Modified": "yesterday", "Link": "<https://api.github.com/user/repos?page=2>; rel=\"next\""]), response("", status: 304)])
    let client = GitHubClient(token: "test-value", transport: await stub.transport)
    let first = try await client.request("/user/repos")
    let second = try await client.request("/user/repos")
    #expect(first.data == second.data)
    #expect(second.nextURL?.query == "page=2")
    let requests = await stub.requests
    #expect(requests[1].value(forHTTPHeaderField: "If-None-Match") == "tag")
    #expect(requests[1].value(forHTTPHeaderField: "If-Modified-Since") == "yesterday")
}

@Test func credentialsNeverFollowAnExternalPaginationURL() async throws {
    let client = GitHubClient(token: "test-value", transport: HTTPTransport { _ in throw GitHubError.malformedResponse })
    await #expect(throws: GitHubError.invalidURL) { try await client.request("https://example.com/steal") }
    await #expect(throws: GitHubError.invalidURL) { try await client.request("https://api.github.com.evil.example/steal") }
}

@Test func offlineCacheIsExplicitAndCanBeCleared() async throws {
    let stub = Stub([response("{\"name\":\"demo\"}"), response("", status: 204)])
    let client = GitHubClient(token: "test-value", transport: await stub.transport)
    _ = try await client.request("/user")
    await stub.setOffline()
    let cached = try await client.request("/user")
    #expect(cached.isOffline)
    await client.clearCache()
    await #expect(throws: URLError.self) { try await client.request("/user") }
}

@Test func successfulMutationInvalidatesCachedResourceBodies() async throws {
    let stub = Stub([response("{\"name\":\"old\"}"), response("{\"name\":\"new\"}")])
    let client = GitHubClient(token: "test-value", transport: await stub.transport)
    _ = try await client.request("/repos/demo/project")
    _ = try await client.request("/repos/demo/project", method: "PATCH", body: .object(["name": .string("new")]))
    await stub.setOffline()
    await #expect(throws: URLError.self) { try await client.request("/repos/demo/project") }
}

@Test func separateAccountDirectoriesNeverReturnEachOthersPrivateCache() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let firstStub = Stub([response("{\"private\":true,\"name\":\"private-project\"}")])
    let first = GitHubClient(token: "first-test-value", transport: await firstStub.transport, cacheDirectory: root.appendingPathComponent("first"))
    _ = try await first.request("/user/repos")
    let secondStub = Stub([]); await secondStub.setOffline()
    let second = GitHubClient(token: "second-test-value", transport: await secondStub.transport, cacheDirectory: root.appendingPathComponent("second"))
    await #expect(throws: URLError.self) { try await second.request("/user/repos") }
}

@Test func permissionAndRateLimitErrorsAreDistinct() async throws {
    let stub = Stub([response("{\"message\":\"policy\"}", status: 403), response("{}", status: 429, headers: ["Retry-After": "20"])])
    let client = GitHubClient(token: "test-value", transport: await stub.transport)
    await #expect(throws: GitHubError.forbidden("policy")) { try await client.request("/user") }
    do { _ = try await client.request("/user"); Issue.record("Expected rate limit") }
    catch GitHubError.rateLimited(let until) { #expect(until.timeIntervalSinceNow > 10) }
}

@Test func loadingPersistedPagesCannotExceedTheMemoryBudget() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let body = Data(repeating: 65, count: 1024 * 1024)
    // Simulate cached pages left by an earlier app session. Disk pruning happens
    // on writes; the read path must independently enforce its own memory bound.
    for index in 0..<40 {
        let key = "https://api.github.com/pages/\(index)|application/vnd.github+json"
        var hash: UInt64 = 14695981039346656037
        for byte in key.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        let entry: [String: Any] = ["data": body.base64EncodedString(), "headers": [:], "saved": Date().timeIntervalSinceReferenceDate]
        try JSONSerialization.data(withJSONObject: entry).write(to: directory.appendingPathComponent(String(hash, radix: 16) + ".json"))
    }
    let stub = Stub([]); await stub.setOffline()
    let reader = GitHubClient(token: "test-value", transport: await stub.transport, cacheDirectory: directory)
    for index in 0..<40 {
        #expect(try await reader.request("/pages/\(index)").isOffline)
        #expect(await reader.cachedByteCount <= 32 * 1024 * 1024)
    }
}

@Test func graphQLReportsErrorsEvenWithHTTP200() async throws {
    let stub = Stub([response("{\"errors\":[{\"message\":\"No access\"}],\"data\":null}")])
    let client = GitHubClient(token: "test-value", transport: await stub.transport)
    await #expect(throws: GitHubError.graphql("No access")) { try await client.graphql("query { viewer { login } }") }
}

@Test func graphQLTracksActualCostAndScopesAreNormalized() async throws {
    let stub = Stub([response("{\"data\":{\"viewer\":{\"login\":\"demo\"},\"rateLimit\":{\"cost\":4,\"remaining\":90,\"resetAt\":\"2026-10-05T20:00:00Z\"}}}", headers: ["X-OAuth-Scopes": "repo, user", "X-Poll-Interval": "120"])])
    let client = GitHubClient(token: "test-value", transport: await stub.transport)
    _ = try await client.graphql("query { viewer { login } rateLimit { cost remaining resetAt } }")
    let rate = await client.rateLimit
    #expect(rate.graphqlCost == 4 && rate.remaining == 90)
    #expect(await client.pollInterval == 120)
    #expect(AuthScopes.missing(requested: ["read:user", "security_events", "workflow"], granted: await client.scopes) == ["workflow"])
    #expect(AuthScopes.missing(requested: ["repo"], granted: nil) == nil)
}

@Test func diskCacheDoesNotPersistAuthorization() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let stub = Stub([response("{\"id\":7}", headers: ["ETag": "v1"])])
    let client = GitHubClient(token: "never-persist-this", transport: await stub.transport, cacheDirectory: directory)
    _ = try await client.request("/user")
    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    #expect(files.count == 1)
    #expect(!(try String(contentsOf: files[0], encoding: .utf8)).contains("never-persist-this"))
}
