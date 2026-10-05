import SwiftUI
import GitHubKit
import Textual

struct MarkdownView: View {
    let text: String
    var body: some View { StructuredText(markdown: text).textual.textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
}

struct ResourceRow: View {
    let value: JSON
    var title: String {
        [value["full_name"].string, value["title"].string, value["display_title"].string, value["name"].string,
         value.at("subject.title").string, value["login"].string, value["filename"].string,
         value.at("commit.message").string, value["key"].string, value["sha"].string].first { !$0.isEmpty } ?? "Item \(value["id"].string)"
    }
    var subtitle: String {
        [value["description"].string, value.at("repository.full_name").string, value["reason"].string,
         value["state"].string, value["status"].string, value["language"].string,
         value.at("user.login").string].filter { !$0.isEmpty }.prefix(2).joined(separator: " · ")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline).lineLimit(3)
                if value["private"].bool { Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary).accessibilityLabel("Private") }
            }
            if !subtitle.isEmpty { Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(3) }
            HStack(spacing: 12) {
                if value["number"].int > 0 { Text("#\(value["number"].int)") }
                if value["stargazers_count"].int > 0 { Label(value["stargazers_count"].string, systemImage: "star") }
                if !value["conclusion"].string.isEmpty { Label(value["conclusion"].string, systemImage: value["conclusion"].string == "success" ? "checkmark.circle" : "xmark.circle") }
            }.font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 4).accessibilityElement(children: .combine)
    }
}

struct FailureView: View {
    let message: String
    var retry: () -> Void
    var body: some View {
        ContentUnavailableView {
            Label("Couldn't load this", systemImage: "exclamationmark.triangle")
        } description: { Text(message) } actions: { Button("Try again", action: retry).buttonStyle(.borderedProminent) }
    }
}

struct DemoBanner: View {
    @Environment(Session.self) private var session
    var body: some View {
        if session.isDemo { Label("Demo · sample data", systemImage: "leaf").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(6).background(.background) }
    }
}

struct ContributionView: View {
    @Environment(Session.self) private var session
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(session.contributions["totalContributions"].int) contributions").font(.headline)
            if session.contributions.isNull { Button("Load contribution activity") { Task { await session.loadContributions() } } }
            else {
                ScrollView(.horizontal) {
                    HStack(spacing: 3) {
                        ForEach(Array(session.contributions["weeks"].array.enumerated()), id: \.offset) { _, week in
                            VStack(spacing: 3) {
                                ForEach(Array(week["contributionDays"].array.enumerated()), id: \.offset) { _, day in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(day["contributionCount"].int == 0 ? Color.secondary.opacity(0.14) : Color.teal.opacity(0.25 + min(Double(day["contributionCount"].int) * 0.15, 0.75)))
                                        .frame(width: 12, height: 12)
                                        .accessibilityLabel("\(day["date"].string), \(day["contributionCount"].int) contributions")
                                }
                            }
                        }
                    }
                }.defaultScrollAnchor(.trailing)
                Text("Activity over the past year").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 6)
    }
}
