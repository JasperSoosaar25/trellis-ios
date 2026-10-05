import SwiftUI

@main struct TrellisApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var session = Session()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            Group {
                if session.restoring { ProgressView("Restoring your session…") }
                else if session.signedIn { AppShell() }
                else { LoginView() }
            }
            .environment(session)
            .modifier(ScreenshotAppearance())
            .tint(.teal)
            .sheet(item: $session.webRoute) { route in BrowserView(url: route.url) }
            .alert("Trellis", isPresented: Binding(get: { session.signedIn && session.error != nil }, set: { if !$0 { session.error = nil } })) { Button("OK") { session.error = nil } } message: { Text(session.error ?? "") }
            .onChange(of: phase) { _, value in if value == .background { BackgroundRefresh.schedule() } }
        }
    }
}

private struct ScreenshotAppearance: ViewModifier {
    @Environment(\.dynamicTypeSize) private var textSize
    func body(content: Content) -> some View {
        let demo = ProcessInfo.processInfo.arguments.contains("--demo")
        content
            .preferredColorScheme(demo && ProcessInfo.processInfo.arguments.contains("--dark") ? .dark : nil)
            .environment(\.dynamicTypeSize, demo && ProcessInfo.processInfo.arguments.contains("--large-text") ? .accessibility3 : textSize)
    }
}
