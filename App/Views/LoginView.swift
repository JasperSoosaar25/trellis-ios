import SwiftUI
import GitHubKit

struct LoginView: View {
    @Environment(Session.self) private var session
    @State private var token = ""
    @State private var clientID = Bundle.main.object(forInfoDictionaryKey: "GHClientID") as? String ?? ""
    @State private var administration = false
    @State private var code: DeviceCode?
    @State private var busy = false
    @State private var error: String?
    @State private var authorization: Task<Void, Never>?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 44)).foregroundStyle(.teal).accessibilityHidden(true)
                        Text("A place for your work to grow.").font(.title2.bold())
                        Text("Trellis is an unofficial client for GitHub. Browse code, collaborate, and manage your repositories.").foregroundStyle(.secondary)
                    }.padding(.vertical, 12)
                }
                Section("Sign in with a token") {
                    SecureField("Personal access token", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Sign in") { loginWithToken() }.disabled(token.isEmpty || busy)
                    Button("Create a token on GitHub", systemImage: "safari") { session.browse("/settings/tokens") }
                }
                Section {
                    TextField("OAuth client ID", text: $clientID).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Toggle("Include administration permissions", isOn: $administration)
                    DisclosureGroup("Requested permissions") { Text((administration ? AuthScopes.administration : AuthScopes.basic).joined(separator: ", ")).font(.footnote).textSelection(.enabled) }
                    if let code {
                        Text(code.userCode).font(.title.monospaced().bold()).textSelection(.enabled)
                        Text("Enter this code at GitHub, then return here. Authorization completes automatically.").font(.footnote)
                        Link("Open verification page", destination: code.verificationURI)
                        Button("Cancel sign-in", role: .cancel) { authorization?.cancel(); busy = false; self.code = nil }
                    } else { Button("Use device sign-in") { startDeviceFlow() }.disabled(clientID.isEmpty || busy) }
                } header: { Text("Device sign-in") } footer: { Text("Use the public client ID of an OAuth App with Device Flow enabled. No client secret is needed.") }
                if busy { ProgressView("Waiting for authorization…") }
                if let message = error ?? session.error { Section { Text(message).foregroundStyle(.red).textSelection(.enabled) } }
                Section { Button("Explore the demo", systemImage: "leaf") { session.isDemo = true; session.profile = Demo.profile; session.contributions = Demo.contributions } }
            }
            .navigationTitle("Trellis")
        }.onDisappear { authorization?.cancel() }
    }
    private func loginWithToken() {
        busy = true; error = nil
        authorization = Task {
            defer { busy = false }
            do { try await session.authenticate(token); token = "" }
            catch { self.error = error.localizedDescription }
        }
    }
    private func startDeviceFlow() {
        busy = true; error = nil
        let id = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let scopes = administration ? AuthScopes.administration : AuthScopes.basic
        session.requestedScopes = scopes
        authorization = Task {
            defer { busy = false; code = nil }
            do {
                let flow = DeviceFlow(); let grant = try await flow.start(clientID: id, scopes: scopes)
                code = grant
                let credential = try await flow.poll(clientID: id, code: grant)
                try Task.checkCancellation(); try await session.authenticate(credential)
            } catch is CancellationError { } catch { self.error = error.localizedDescription }
        }
    }
}
