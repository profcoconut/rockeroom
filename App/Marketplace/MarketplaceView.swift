import SwiftUI
import SharedKit

struct MarketplaceView: View {
    let projection: EvidenceProjection

    var body: some View {
        List {
            Section("Overview") {
                Text(projection.summaryText)
                    .accessibilityIdentifier("marketplaceSummaryText")

                if !projection.stateBadges.isEmpty {
                    badgeRow(projection.stateBadges)
                        .accessibilityIdentifier("marketplaceSummaryBadges")
                }
            }

            Section("Evidence") {
                if projection.cards.isEmpty {
                    Text(projection.emptyMessage ?? "No evidence available yet.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("marketplaceEmptyState")
                } else {
                    ForEach(projection.cards) { card in
                        cardView(card)
                            .accessibilityIdentifier("marketplaceCard.\(card.candidateID)")
                    }
                }
            }
        }
        .navigationTitle("Marketplace")
        .accessibilityIdentifier("marketplaceScreen")
    }

    private func cardView(_ card: EvidenceCard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(card.rank). \(card.label)")
                        .font(.headline)
                    Text(card.scoreText)
                        .font(.subheadline.weight(.semibold))
                    Text(card.summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    ForEach(card.markers, id: \.rawValue) { marker in
                        markerBadge(marker.label)
                    }
                }
            }

            if !card.stateBadges.isEmpty {
                badgeRow(card.stateBadges)
            }

            ForEach(Array(card.metrics.prefix(2))) { metric in
                HStack {
                    Text(metric.name.capitalized)
                    Spacer()
                    Text(metricValue(metric))
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }

            if let proof = card.proof, let delta = proof.deltas.first {
                Label(deltaSummary(delta), systemImage: delta.isImprovement ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func badgeRow(_ badges: [EvidenceBadge]) -> some View {
        HStack(spacing: 8) {
            ForEach(badges, id: \.rawValue) { badge in
                markerBadge(badge.label)
            }
        }
    }

    private func markerBadge(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }

    private func metricValue(_ metric: ProbeMetric) -> String {
        if metric.unit == "ms" {
            return "\(Int(metric.value))\(metric.unit)"
        }
        return "\(Int(metric.value.rounded()))\(metric.unit)"
    }

    private func deltaSummary(_ delta: ProofDelta) -> String {
        let value = delta.candidateValue - delta.currentValue
        let sign = value > 0 ? "+" : ""
        if delta.unit == "ms" {
            return "\(delta.metricName.capitalized): \(sign)\(Int(value))\(delta.unit)"
        }
        return "\(delta.metricName.capitalized): \(sign)\(Int(value.rounded()))\(delta.unit)"
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

private extension EvidenceCardMarker {
    var label: String {
        switch self {
        case .current:
            return "Current"
        case .recommended:
            return "Recommended"
        case .pinned:
            return "Pinned"
        }
    }
}
