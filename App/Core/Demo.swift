import Foundation
import GitHubKit

enum Demo {
    static func json(_ source: String) -> JSON { (try? JSON.decode(Data(source.utf8))) ?? .null }
    static let profile = json(###"{"login":"river-demo","name":"River Morgan","bio":"Building useful things, one branch at a time.","public_repos":12,"followers":48,"following":21,"html_url":"https://github.com","id":101}"###)
    static let repositories = json(###"[{"id":201,"name":"garden-notes","full_name":"river-demo/garden-notes","description":"A small place for ideas to grow.","language":"Swift","stargazers_count":128,"forks_count":14,"open_issues_count":8,"default_branch":"main","owner":{"login":"river-demo"},"private":false},{"id":202,"name":"weather-station","full_name":"river-demo/weather-station","description":"Local forecasts, thoughtfully presented.","language":"TypeScript","stargazers_count":64,"forks_count":7,"open_issues_count":3,"default_branch":"main","owner":{"login":"river-demo"},"private":false},{"id":203,"name":"field-journal","full_name":"river-demo/field-journal","description":"Notes and experiments from the field.","language":"Python","stargazers_count":32,"default_branch":"main","owner":{"login":"river-demo"},"private":true}]"###)
    static let issues = json(###"[{"id":301,"number":24,"title":"Improve accessibility in the file browser","state":"open","body":"## A more readable browser\n\n- [x] Add Dynamic Type\n- [ ] Check VoiceOver navigation\n\nThanks for helping make this better.","user":{"login":"sky-demo"},"comments":4,"labels":[{"name":"enhancement"}]},{"id":302,"number":23,"title":"Add a quiet mode for notifications","state":"open","body":"Keep focused work peaceful.","user":{"login":"river-demo"},"comments":2,"labels":[{"name":"discussion"}]}]"###)
    static let notifications = json(###"[{"id":"401","unread":true,"reason":"mention","subject":{"title":"Improve accessibility in the file browser","type":"Issue","url":"https://api.github.com/repos/river-demo/garden-notes/issues/24"},"repository":{"full_name":"river-demo/garden-notes"}},{"id":"402","unread":true,"reason":"review_requested","subject":{"title":"Polish the search experience","type":"PullRequest","url":"https://api.github.com/repos/river-demo/weather-station/pulls/18"},"repository":{"full_name":"river-demo/weather-station"}}]"###)
    static let workflows = json(###"{"workflows":[{"id":501,"name":"Build and test","path":".github/workflows/build.yml","state":"active"},{"id":502,"name":"Deploy preview","path":".github/workflows/deploy.yml","state":"active"}]}"###)
    static let runs = json(###"{"workflow_runs":[{"id":601,"name":"Build and test","display_title":"Improve accessibility in the file browser","status":"completed","conclusion":"success","run_number":42,"head_branch":"main"},{"id":602,"name":"Build and test","display_title":"Polish the search experience","status":"in_progress","run_number":41,"head_branch":"feature/search"}]}"###)
    static let comments = json(###"[{"id":701,"body":"Thanks for checking. The next update improves readability.","user":{"login":"river-demo"}}]"###)
    static var contributions: JSON {
        .object(["totalContributions": .number(348), "weeks": .array((0..<18).map { week in
            .object(["contributionDays": .array((0..<7).map { day in .object(["date": .string("Demo day \(week * 7 + day + 1)"), "contributionCount": .number(Double((week * 11 + day * 7) % 6))]) })])
        })])
    }
    static func resource(_ path: String) -> JSON {
        if path.contains("/notifications") { return notifications }
        if path.contains("/search/repositories") { return .object(["items": repositories]) }
        if path.contains("/search/issues") { return .object(["items": issues]) }
        if path.contains("/workflows") { return workflows }
        if path.contains("/actions/runs") { return runs }
        if path.contains("/issues/") && path.contains("/comments") { return comments }
        if path.contains("/issues/") { return issues[0] }
        if path.contains("/issues") { return issues }
        if path.contains("/readme") { return .object(["content": .string(Data("# Garden Notes\n\nA small place for ideas to grow.\n\n## Getting started\n\nPlant an idea. Make a branch. Share what you learn.\n\n| Area | Status |\n| --- | --- |\n| Accessibility | Growing |\n| Search | Ready |".utf8).base64EncodedString())]) }
        if path.contains("/contents") { return json(###"[{"name":"Sources","path":"Sources","type":"dir","sha":"demo-dir"},{"name":"README.md","path":"README.md","type":"file","sha":"demo-file"},{"name":"Package.swift","path":"Package.swift","type":"file","sha":"demo-package"}]"###) }
        if path.contains("/repos/river-demo/") { return repositories[0] }
        if path.contains("/user/repos") { return repositories }
        if path == "/user" { return profile }
        return .array([])
    }
}
