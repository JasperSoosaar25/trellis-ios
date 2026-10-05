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
            .tint(.teal)
            .sheet(item: $session.webRoute) { route in BrowserView(url: route.url) }
            .onChange(of: phase) { _, value in if value == .background { BackgroundRefresh.schedule() } }
        }
    }
}
