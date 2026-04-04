import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: AutoModeViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                recommendationCard
                metricsCard
                benchmarkCard
                supportCard
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.99, blue: 1.0),
                    Color(red: 0.94, green: 0.96, blue: 0.99)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Home")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RockeRoom")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(viewModel.subscriptionDisplayName)
                .font(.headline)
            Text("Import once, benchmark when you want, then inspect details in Expert Console.")
                .foregroundStyle(.secondary)
        }
    }

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(viewModel.currentTitle)
                    .font(.title3.weight(.bold))
                Spacer()
                Text(viewModel.homeRecommendationStatus)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.08), in: Capsule())
            }

            Text(viewModel.currentSetupText)
                .font(.headline)
                .accessibilityIdentifier("currentSetupText")

            Text(viewModel.homeRecommendationSubtitle)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("recommendationSummaryText")

            if viewModel.pinnedProvider {
                Text("Manual selection is active. Unpin it from Expert Console to return to automatic recommendation.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("pinnedProviderBanner")
            }
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .accessibilityIdentifier("recommendationCard")
    }

    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Benchmark summary")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(viewModel.homeMetricSummaries) { metric in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(metric.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(metric.value)
                            .font(.title3.weight(.bold))
                        if let note = metric.note {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(red: 0.96, green: 0.97, blue: 0.99), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .accessibilityIdentifier("homeMetric.\(metric.id)")
                }
            }
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var benchmarkCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Benchmark")
                    .font(.headline)
                Spacer()
                Text(viewModel.tunnelStatusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let refreshHintText = viewModel.refreshHintText {
                Text(refreshHintText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("refreshHintText")
            } else {
                Text(viewModel.recommendationSummaryText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                viewModel.optimize()
            } label: {
                HStack {
                    if viewModel.isBenchmarkInFlight {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(viewModel.benchmarkActionTitle)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(viewModel.isBenchmarkInFlight ? Color.gray.opacity(0.6) : Color.black)
            )
            .disabled(viewModel.isBenchmarkInFlight)
            .accessibilityIdentifier("benchmarkButton")
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var supportCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Need more detail?")
                .font(.headline)
            Text("Use Expert Console for ranked candidates, manual pinning, and the full metric breakdown. Marketplace is a placeholder in this version.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(Color(red: 0.95, green: 0.97, blue: 0.99), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
