import Foundation
import Testing
@testable import GitHubKit

actor WaitRecorder {
    var values: [Int] = []
    func record(_ value: Int) { values.append(value) }
}

@Test func deviceFlowSlowsDownAndNeverNeedsASecret() async throws {
    let stub = Stub([
        response("{\"device_code\":\"device\",\"user_code\":\"ABCD-EFGH\",\"verification_uri\":\"https://github.com/login/device\",\"expires_in\":900,\"interval\":5}"),
        response("{\"error\":\"authorization_pending\"}"),
        response("{\"error\":\"slow_down\",\"interval\":10}"),
        response("{\"access_token\":\"stub-token\"}")
    ])
    let waits = WaitRecorder()
    let flow = DeviceFlow(transport: await stub.transport, wait: { await waits.record($0) })
    let code = try await flow.start(clientID: "public-client", scopes: ["repo"])
    #expect(try await flow.poll(clientID: "public-client", code: code) == "stub-token")
    #expect(await waits.values == [5, 5, 10])
    let requests = await stub.requests
    #expect(requests.allSatisfy { !String(decoding: $0.httpBody ?? Data(), as: UTF8.self).contains("client_secret") })
}

@Test func deviceFlowExpiresAndCancels() async throws {
    let stub = Stub([response("{\"error\":\"expired_token\"}")])
    let code = try JSONDecoder().decode(DeviceCode.self, from: Data("{\"device_code\":\"d\",\"user_code\":\"u\",\"verification_uri\":\"https://github.com/login/device\",\"expires_in\":900,\"interval\":5}".utf8))
    let flow = DeviceFlow(transport: await stub.transport, wait: { _ in })
    await #expect(throws: GitHubError.deviceFlow("The code expired. Start sign-in again.")) { try await flow.poll(clientID: "c", code: code) }
    let cancellation = DeviceFlow(transport: await stub.transport, wait: { _ in throw CancellationError() })
    await #expect(throws: CancellationError.self) { try await cancellation.poll(clientID: "c", code: code) }
}

@Test func workflowInputsProduceTypedJSONAndCatchInvalidChoices() throws {
    let source = """
    name: Deploy
    on:
      workflow_dispatch:
        inputs:
          target:
            description: Deployment target
            type: choice
            required: true
            options:
              - staging
              - production
          dry_run:
            type: boolean
            default: 'true'
          count:
            type: number
            default: '2'
    jobs:
      deploy:
        runs-on: ubuntu-latest
    """
    let definition = WorkflowDefinition.parse(source)
    #expect(definition.inputs.count == 3)
    #expect(definition.supportsDispatch && !definition.needsAdvancedEditor)
    let result = try definition.values(["target": "staging"])
    #expect(result["dry_run"] == .bool(true))
    #expect(result["count"] == .number(2))
    #expect(throws: GitHubError.self) { try definition.values(["target": "invalid"]) }
}

@Test func complexWorkflowYAMLIsNotSilentlyMisrepresented() {
    #expect(WorkflowDefinition.parse("on:\n  workflow_dispatch: {inputs: {a: {type: string}}}").needsAdvancedEditor)
    #expect(WorkflowDefinition.parse("on:\n  workflow_dispatch:\n    inputs:\n      a:\n        default: ${{ github.ref }}").needsAdvancedEditor)
}

@Test func diffPositionsRemainCorrectAcrossMultipleHunks() {
    let lines = DiffLine.parse("@@ -2,3 +2,3 @@\n same\n-old\n+new\n same\n@@ -20 +20 @@\n-x\n+y")
    #expect(lines[2].oldLine == 3 && lines[2].newLine == nil)
    #expect(lines[3].newLine == 3)
    #expect(lines.last?.newLine == 20)
}

@Test func ansiResetsAndBoldAreApplied() {
    let spans = ANSI.parse("plain\u{001B}[1;31mred\u{001B}[0mplain")
    #expect(spans.map(\.text).joined() == "plainredplain")
    #expect(spans[1].color == 1 && spans[1].bold)
    #expect(spans[2].color == nil && !spans[2].bold)
}

@Test func pathAndQueryDoNotConfuseBranchNamesWithURLStructure() {
    #expect(URLCoding.segment("feature/foo") == "feature%2Ffoo")
    #expect(URLCoding.path("dir/a b.swift") == "dir/a%20b.swift")
    #expect(URLCoding.query(["q": "a&b+c"]).contains("%26"))
    #expect(URLCoding.query(["q": "a+b"]) == "q=a%2Bb")
    let json = JSON.object(["large": .number(9876543210), "null": .null, "array": .array([.bool(true)])])
    #expect((try? JSON.decode(json.encoded())) == json)
}
