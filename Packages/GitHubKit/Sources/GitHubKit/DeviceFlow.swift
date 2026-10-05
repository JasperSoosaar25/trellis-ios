import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct DeviceCode: Codable, Sendable, Equatable {
    public let deviceCode: String
    public let userCode: String
    public let verificationURI: URL
    public let expiresIn: Int
    public let interval: Int
    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code", userCode = "user_code", verificationURI = "verification_uri", expiresIn = "expires_in", interval
    }
}

public enum AuthScopes {
    public static let basic = ["repo", "workflow", "gist", "notifications", "read:org", "read:user", "project", "read:packages", "codespace", "security_events"]
    public static let administration = basic + ["delete_repo", "admin:org", "admin:repo_hook", "write:packages", "delete:packages", "admin:public_key", "admin:gpg_key", "admin:ssh_signing_key"]
    public static func missing(requested: [String], granted: Set<String>?) -> [String]? {
        guard let granted else { return nil }
        let implied: [String: Set<String>] = ["user": ["read:user", "user:email", "user:follow"], "admin:org": ["write:org", "read:org"], "write:org": ["read:org"], "repo": ["public_repo", "repo:status", "repo_deployment", "repo:invite", "security_events"], "project": ["read:project"], "write:packages": ["read:packages"], "admin:public_key": ["write:public_key", "read:public_key"], "admin:gpg_key": ["write:gpg_key", "read:gpg_key"]]
        let expanded = granted.reduce(into: granted) { result, scope in result.formUnion(implied[scope] ?? []) }
        return requested.filter { !expanded.contains($0) }
    }
}

public struct DeviceFlow: Sendable {
    private let transport: HTTPTransport
    private let wait: @Sendable (Int) async throws -> Void
    public init(transport: HTTPTransport = .live, wait: @escaping @Sendable (Int) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }) {
        self.transport = transport; self.wait = wait
    }
    public func start(clientID: String, scopes: [String]) async throws -> DeviceCode {
        let data = try await post("device/code", ["client_id": clientID, "scope": scopes.joined(separator: " ")])
        if let root = try? JSON.decode(data), !root["error"].isNull { throw GitHubError.deviceFlow(root["error_description"].string) }
        return try JSONDecoder().decode(DeviceCode.self, from: data)
    }
    public func poll(clientID: String, code: DeviceCode) async throws -> String {
        let expiry = Date().addingTimeInterval(Double(code.expiresIn)); var interval = max(1, code.interval)
        while Date() < expiry {
            try Task.checkCancellation(); try await wait(interval)
            let data = try await post("oauth/access_token", ["client_id": clientID, "device_code": code.deviceCode, "grant_type": "urn:ietf:params:oauth:grant-type:device_code"])
            let response = try JSON.decode(data)
            if !response["access_token"].string.isEmpty { return response["access_token"].string }
            switch response["error"].string {
            case "authorization_pending": continue
            case "slow_down": interval = max(interval + 5, response["interval"].int)
            case "expired_token", "token_expired": throw GitHubError.deviceFlow("The code expired. Start sign-in again.")
            case "access_denied": throw GitHubError.deviceFlow("Authorization was declined. Start again when ready.")
            default: throw GitHubError.deviceFlow(response["error_description"].string.isEmpty ? "Device Flow is not enabled or the client ID is invalid." : response["error_description"].string)
            }
        }
        throw GitHubError.deviceFlow("The code expired. Start sign-in again.")
    }
    private func post(_ path: String, _ form: [String: String]) async throws -> Data {
        let url = URL(string: "https://github.com/login/" + path)!
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = URLCoding.query(form).data(using: .utf8)
        let response = try await transport.send(request)
        guard (200..<300).contains(response.status) else { throw GitHubError.http(response.status, "Device authorization service unavailable.") }
        return response.data
    }
}
