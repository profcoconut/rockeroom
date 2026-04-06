import SwiftUI

struct RouteContextInspectorView: View {
    let summary: RouteContextSummary?
    let rows: [RouteContextInspectorRow]

    var body: some View {
        if rows.isEmpty {
            Text("No route context yet. Run Benchmark to inspect the current environment, destination, provider, and strategy.")
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if let summary {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(summary.title)
                                    .font(.headline)
                                    .accessibilityIdentifier("routeContextSummaryTitle")
                                Text(summary.detailText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("routeContextSummaryDetail")
                            }
                            Spacer()
                            statusBadge(summary.statusBadge)
                                .accessibilityIdentifier("routeContextSummaryBadge")
                        }
                    }
                }

                ForEach(rows) { row in
                    HStack {
                        Text(row.title)
                        Spacer()
                        Text(row.value)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("routeContextRow.\(row.id)")
                }
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .contain)
        }
    }

    private func statusBadge(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }
}
