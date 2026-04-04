import SwiftUI
import SharedKit

struct MarketplaceTeaserView: View {
    let projection: EvidenceProjection
    let onOpenMarketplace: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(projection.headline)
                .font(.headline)
            Text(projection.summaryText)
                .foregroundStyle(.secondary)

            if projection.cards.isEmpty, let emptyMessage = projection.emptyMessage {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("marketplaceTeaserEmptyMessage")
            } else {
                HStack {
                    Label("\(projection.cards.count) evidence cards", systemImage: "checkmark.seal")
                    Spacer()
                    Text(markerSummary)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("marketplaceTeaserSummary")
            }

            if !projection.stateBadges.isEmpty {
                HStack(spacing: 8) {
                    ForEach(projection.stateBadges, id: \.rawValue) { badge in
                        Text(badge.label)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                }
                .accessibilityIdentifier("marketplaceTeaserBadges")
            }

            Button {
                onOpenMarketplace()
            } label: {
                Label("Open Marketplace", systemImage: "square.grid.2x2")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("openMarketplaceButton")
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var markerSummary: String {
        if projection.cards.contains(where: { $0.markers.contains(.pinned) }) {
            return "Pinned"
        }
        if projection.stateBadges.contains(.stale) {
            return "Stale"
        }
        return "Tertiary"
    }
}

private extension EvidenceBadge {
    var label: String {
        switch self {
        case .stale:
            return "Stale"
        case .partial:
            return "Partial"
        case .degraded:
            return "Degraded"
        }
    }
}
