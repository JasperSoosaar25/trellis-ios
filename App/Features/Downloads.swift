import SwiftUI
import GitHubKit

final class DownloadRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        guard request.url?.scheme == "https" else { completionHandler(nil); return }
        var next = request
        if request.url?.host != "api.github.com" { next.setValue(nil, forHTTPHeaderField: "Authorization") }
        completionHandler(next)
    }
}

enum APIFileDownload {
    static func fetch(_ path: String) async throws -> URL {
        guard let token = Keychain.read() else { throw GitHubError.unauthorized }
        guard let url = URL(string: "https://api.github.com" + path), url.host == "api.github.com", url.user == nil, url.password == nil else { throw GitHubError.invalidURL }
        var request = URLRequest(url: url); request.timeoutInterval = 60
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
        let downloader = URLSession(configuration: .ephemeral, delegate: DownloadRedirectDelegate(), delegateQueue: nil)
        defer { downloader.finishTasksAndInvalidate() }
        let (temporary, response) = try await downloader.download(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            try? FileManager.default.removeItem(at: temporary)
            throw GitHubError.http((response as? HTTPURLResponse)?.statusCode ?? 0, "Download unavailable. Check permissions, rate limits, and whether logs are ready.")
        }
        return temporary
    }
}

struct ArtifactList: View {
    let repo: String
    var runID: String? = nil
    @Environment(Session.self) private var session
    @State private var artifacts: [ResourceItem] = []
    @State private var error: String?
    @State private var download: SharedFile?
    @State private var busy = false
    @State private var next: URL?
    var path: String { "/repos/\(repo)/actions/" + (runID.map { "runs/\($0)/" } ?? "") + "artifacts?per_page=100" }
    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.red); Button("Retry") { Task { await load() } } }
            if artifacts.isEmpty && error == nil { ContentUnavailableView("No artifacts", systemImage: "archivebox") }
            ForEach(artifacts) { artifact in
                VStack(alignment: .leading) {
                    ResourceRow(value: artifact.value)
                    LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: Int64(artifact.value["size_in_bytes"].int), countStyle: .file))
                    if artifact.value["expired"].bool { Text("Expired").foregroundStyle(.secondary) }
                    else { Button("Download & share", systemImage: "square.and.arrow.down") { Task { await fetch(artifact) } }.disabled(busy || session.isDemo) }
                }
            }
            if next != nil { Button("Load more") { Task { await load(more: true) } } }
            if busy { ProgressView("Downloading…") }
            Button("Open artifacts on GitHub") { session.browse("/\(repo)/actions") }
        }.navigationTitle("Artifacts").task { await load() }.refreshable { await load() }
            .sheet(item: $download) { file in ShareFileView(url: file.url).onDisappear { try? FileManager.default.removeItem(at: file.url); download = nil } }
    }
    private func load(more: Bool = false) async {
        do { let result = try await session.request(more ? next!.absoluteString : path); let page = result.json["artifacts"].array.map { ResourceItem($0) }; artifacts = more ? artifacts + page : page; next = result.nextURL; error = nil } catch { self.error = error.localizedDescription }
    }
    private func fetch(_ item: ResourceItem) async {
        guard let token = Keychain.read(), let url = URL(string: "https://api.github.com/repos/\(repo)/actions/artifacts/\(item.id)/zip") else { return }
        busy = true; defer { busy = false }
        do {
            var request = URLRequest(url: url); request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization"); request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let downloader = URLSession(configuration: .ephemeral, delegate: DownloadRedirectDelegate(), delegateQueue: nil)
            defer { downloader.finishTasksAndInvalidate() }
            let (temporary, response) = try await downloader.download(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw GitHubError.http((response as? HTTPURLResponse)?.statusCode ?? 0, "Artifact unavailable or expired.") }
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-\(URLCoding.segment(item.value["name"].string)).zip")
            try FileManager.default.moveItem(at: temporary, to: destination); download = SharedFile(url: destination); error = nil
        } catch { self.error = error.localizedDescription }
    }
}
struct SharedFile: Identifiable { let id = UUID(); let url: URL }
struct ShareFileView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
