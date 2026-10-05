import SwiftUI
import GitHubKit

struct BillingUsageView: View {
    let account: String
    let organization: Bool
    @Environment(Session.self) private var session
    @State private var report = "usage"
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var month = Calendar.current.component(.month, from: Date())
    private var endpoint: String {
        let kind = organization ? report : "ai_credit/usage"
        let owner = organization ? "organizations" : "users"
        return "/\(owner)/\(URLCoding.segment(account))/settings/billing/\(kind)?year=\(year)&month=\(month)"
    }
    var body: some View {
        VStack(spacing: 0) {
            Form {
                if organization {
                    Picker("Report", selection: $report) {
                        Text("All products, including Actions").tag("usage")
                        Text("Copilot AI credits").tag("ai_credit/usage")
                        Text("Copilot premium requests").tag("premium_request/usage")
                    }
                }
                Stepper("Year: \(String(year))", value: $year, in: 2024...Calendar.current.component(.year, from: Date()))
                Picker("Month", selection: $month) { ForEach(1...12, id: \.self) { Text(Calendar.current.monthSymbols[$0 - 1]).tag($0) } }
                Text(organization ? "Organization administrators can read available billing reports. All-product usage requires the enhanced billing platform. For personal repositories, open your account's usage page below." : "Personal API reports cover a Copilot plan billed directly to you. Actions and organization-paid Copilot usage are available in their respective billing pages.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Open billing page", systemImage: "safari") {
                    session.browse(organization ? "/organizations/\(account)/settings/billing/usage" : "/settings/billing/usage")
                }
            }.frame(maxHeight: 300)
            ResourceList(title: "Billing usage", path: endpoint, key: "usageItems", webPath: organization ? "/organizations/\(account)/settings/billing/usage" : "/settings/billing/usage")
        }.navigationTitle("Billing usage")
    }
}

struct SponsorsView: View {
    @Environment(Session.self) private var session
    @State private var sponsorships: [ResourceItem] = []
    @State private var loading = true
    @State private var error: String?
    @State private var cursor: String?
    @State private var more = false
    var body: some View {
        List {
            if loading && sponsorships.isEmpty { ProgressView("Loading sponsorships…") }
            if let error { Text(error).foregroundStyle(.red); Button("Retry") { Task { await load() } } }
            if !loading && sponsorships.isEmpty && error == nil { ContentUnavailableView("No sponsorships", systemImage: "heart", description: Text("Your active sponsorships will appear here.")) }
            ForEach(sponsorships) { sponsorship in
                VStack(alignment: .leading, spacing: 6) {
                    Text(sponsorship.value.at("sponsorable.login").string).font(.headline)
                    LabeledContent("Status", value: sponsorship.value["isActive"].bool ? "Active" : "Inactive")
                    LabeledContent("Payment", value: sponsorship.value["isOneTimePayment"].bool ? "One time" : "Recurring")
                    LabeledContent("Tier", value: sponsorship.value.at("tier.name").string)
                    LabeledContent(sponsorship.value["isOneTimePayment"].bool ? "Amount (USD)" : "Monthly USD", value: sponsorship.value.at("tier.monthlyPriceInDollars").string)
                    Button("Manage sponsorship") { session.browse("/sponsors/\(sponsorship.value.at("sponsorable.login").string)") }
                }
            }
            if more { Button("Load more") { Task { await load(next: true) } }.disabled(loading) }
            Button("Explore Sponsors", systemImage: "safari") { session.browse("/sponsors") }
            Button("Manage billing & payments", systemImage: "creditcard") { session.browse("/settings/billing") }
        }.navigationTitle("Sponsors").task { await load() }.refreshable { await load() }
    }
    private func load(next: Bool = false) async {
        guard !loading || sponsorships.isEmpty else { return }
        loading = true; defer { loading = false }
        do {
            let result = try await session.graphql("""
            query($after:String){viewer{sponsorshipsAsSponsor(first:50,after:$after){nodes{
            id isActive isOneTimePayment createdAt sponsorable{...on User{login} ...on Organization{login}}
            tier{name monthlyPriceInDollars}
            }pageInfo{hasNextPage endCursor}}}rateLimit{cost remaining resetAt}}
            """, variables: .object(["after": next ? cursor.map(JSON.string) ?? .null : .null]))
            let page = result.at("viewer.sponsorshipsAsSponsor")
            let items = page["nodes"].array.map { ResourceItem($0) }
            sponsorships = next ? sponsorships + items : items
            cursor = page.at("pageInfo.endCursor").string; more = page.at("pageInfo.hasNextPage").bool; error = nil
        } catch { self.error = error.localizedDescription }
    }
}
