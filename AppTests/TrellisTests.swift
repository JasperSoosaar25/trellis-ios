import XCTest
import GitHubKit
import Sodium
@testable import Trellis

@MainActor final class TrellisTests: XCTestCase {
    func testDemoRejectsBothRESTAndGraphQLWrites() async throws {
        let session = Session(restoreStoredSession: false); session.isDemo = true
        do { _ = try await session.request("/user/repos", method: "POST"); XCTFail("Demo must not report a successful write") }
        catch GitHubError.http(let status, _) { XCTAssertEqual(status, 403) }
        do { _ = try await session.graphql("  mutation { deleteProjectV2(input:{projectId:\"fixture\"}){clientMutationId} }"); XCTFail("Demo must reject GraphQL writes too") }
        catch GitHubError.http(let status, _) { XCTAssertEqual(status, 403) }
        let read = try await session.graphql("query { viewer { login } }")
        XCTAssertEqual(read, .object([:]))
    }
    func testFileEditorEncodesUnicodeAndPreservesConflictSHA() throws {
        let value = JSON.object(["content": .string(Data("Hello 🌱".utf8).base64EncodedString()), "sha": .string("expected")])
        let editor = EditorDefinition.file(repo: "sample/project", branch: "main", path: "readme.md", content: value)
        let payload = try XCTUnwrap(editor.transform)(editor.initial)
        XCTAssertEqual(decodeContent(payload), "Hello 🌱")
        XCTAssertEqual(payload["sha"].string, "expected")
        XCTAssertTrue(payload["path"].isNull)
    }
    func testIssueEditsOnlySendWriteFields() {
        let issue = JSON.object(["id": .number(13), "title": .string("Title"), "labels": .array([.object(["name": .string("bug")])]), "assignees": .array([.object(["login": .string("demo")])]), "milestone": .object(["number": .number(3)])])
        let editor = EditorDefinition.issue("sample/project", number: 1, initial: issue)
        XCTAssertTrue(editor.initial["id"].isNull)
        XCTAssertEqual(editor.initial["labels"], .array([.string("bug")]))
        XCTAssertEqual(editor.initial["milestone"].int, 3)
    }
    func testAnonymousSecretEncryptionRoundTrip() throws {
        let sodium = Sodium()
        let pair = try XCTUnwrap(sodium.box.keyPair())
        let plaintext = Array("fixture-only-secret".utf8)
        let encrypted = try XCTUnwrap(sodium.box.seal(message: plaintext, recipientPublicKey: pair.publicKey))
        XCTAssertNotEqual(encrypted, plaintext)
        XCTAssertEqual(sodium.box.open(anonymousCipherText: encrypted, recipientPublicKey: pair.publicKey, recipientSecretKey: pair.secretKey), plaintext)
    }
}
