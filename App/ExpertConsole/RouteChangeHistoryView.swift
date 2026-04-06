import SwiftUI

struct RouteChangeHistoryView: View {
    let rows: [RouteChangeHistoryRow]
    let emptyText: String

    var body: some View {
        if rows.isEmpty {
            Text(emptyText)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("routeHistoryEmptyState")
        } else {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.title)
                                    .font(.headline)
                                Text(row.detailText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 6) {
                                historyBadge(row.badgeText)
                                if row.isCurrent {
                                    historyBadge("Current")
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .accessibilityIdentifier("routeHistoryRow.\(row.id)")
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    private func historyBadge(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }
}
