import SwiftUI
import SharedKit

struct AutoModeView: View {
    @ObservedObject var viewModel: AutoModeViewModel
    let onImportClashSubscription: () -> Void
    let onOpenWhyThis: () -> Void
    let onOpenExpertConsole: () -> Void
    let onOpenMarketplace: () -> Void
    let marketplaceProjection: EvidenceProjection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                recommendationCard
                proofCard
                uncertaintyCard
                actionRow
                marketplaceTeaser
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [
                    Color.white,
                    Color.black.opacity(0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Auto Mode")
                .font(.largeTitle.bold())
            Text("RockeRoom picks the best current setup and shows why.")
                .foregroundStyle(.secondary)
        }
    }

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.currentTitle)
                .font(.headline)
            Text(viewModel.currentSetupText)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("currentSetupText")
            Text(viewModel.recommendationSummaryText)
                .font(.callout)
                .accessibilityIdentifier("recommendationSummaryText")
            if viewModel.pinnedProvider {
                Text("Pinned provider active. Auto-switch is disabled.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("pinnedProviderBanner")
            }

            if case .failed(let message) = viewModel.status {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityIdentifier("recommendationCard")
    }

    private var proofCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Proof")
                .font(.headline)
            ForEach(viewModel.proofRows, id: \.title) { row in
                proofRow(title: row.title, value: row.value)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func proofRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }

    private var uncertaintyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.headline)
            Text(viewModel.tunnelStatusText)
            Text(viewModel.confidenceText)
            Text(viewModel.freshnessText)
                .foregroundStyle(.secondary)
            if let refreshHintText = viewModel.refreshHintText {
                Text(refreshHintText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("refreshHintText")
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var actionRow: some View {
        VStack(spacing: 12) {
            Button {
                onImportClashSubscription()
            } label: {
                Label("Import Clash Subscription", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("importClashSubscriptionButton")

            Button {
                viewModel.optimize()
            } label: {
                Label("Optimize", systemImage: "bolt.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("optimizeButton")

            Button {
                onOpenWhyThis()
            } label: {
                Label("Why this?", systemImage: "questionmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("whyThisButton")

            Button {
                onOpenExpertConsole()
            } label: {
                Label("Open Expert Console", systemImage: "waveform.path.ecg")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("openExpertConsoleButton")
        }
    }

    private var marketplaceTeaser: some View {
        MarketplaceTeaserView(
            projection: marketplaceProjection,
            onOpenMarketplace: onOpenMarketplace
        )
    }
}
