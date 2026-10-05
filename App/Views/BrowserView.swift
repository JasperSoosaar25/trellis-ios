import SwiftUI
import WebKit

struct BrowserView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            WebView(url: url)
                .navigationTitle(url.host ?? "Browser").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                    ToolbarItem(placement: .bottomBar) { ShareLink(item: url) }
                }
                .safeAreaInset(edge: .bottom) { Text("Web features use a separate GitHub browser sign-in.").font(.caption).foregroundStyle(.secondary).padding(8).frame(maxWidth: .infinity).background(.background) }
        }
    }
}
