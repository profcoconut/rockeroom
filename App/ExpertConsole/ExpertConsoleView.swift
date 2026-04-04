import SwiftUI

struct ExpertConsoleView: View {
    @ObservedObject var viewModel: ExpertConsoleViewModel
    let onPinCandidate: (String) -> Void
    let onUnpinCandidate: () -> Void

    var body: some View {
        List {
            Section("Current") {
                row(title: "Current setup", value: viewModel.currentSetupText)
                    .accessibilityIdentifier("expertConsoleCurrentSetupValue")
                row(title: "Confidence", value: viewModel.confidenceText)
                row(title: "Freshness", value: viewModel.freshnessText)
                if let holdReasonText = viewModel.holdReasonText {
                    row(title: "Hold", value: holdReasonText)
                }
            }

            Section("Ranked candidates") {
                if viewModel.rankedCandidates.isEmpty {
                    Text("Run Benchmark from Home to populate ranked candidates.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(viewModel.rankedCandidates) { candidate in
                            candidateRow(candidate)
                        }
                    }
                    .accessibilityIdentifier("expertConsoleCandidateList")
                }
            }

            Section("Evidence") {
                if viewModel.evidenceRows.isEmpty {
                    Text("No benchmark evidence yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.evidenceRows, id: \.0) { row in
                        self.row(title: row.0, value: row.1)
                    }
                }
            }

            Section("Control") {
                row(title: "Manual override", value: viewModel.controlText)
                    .accessibilityIdentifier("expertConsoleControlValue")
            }
        }
        .navigationTitle("Expert Console")
        .accessibilityIdentifier("expertConsoleScreen")
    }

    private func row(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func candidateRow(_ candidate: CandidateRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(candidate.rank). \(candidate.title)")
                        .font(.headline)
                    Text(candidate.scoreText)
                        .font(.subheadline.weight(.semibold))
                    Text(candidate.detailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    if candidate.isCurrent {
                        badge("Current")
                            .accessibilityIdentifier("candidateBadge.current.\(candidate.id)")
                    }
                    if candidate.isRecommended {
                        badge("Recommended")
                            .accessibilityIdentifier("candidateBadge.recommended.\(candidate.id)")
                    }
                    if candidate.isPinned {
                        badge("Pinned")
                            .accessibilityIdentifier("candidateBadge.pinned.\(candidate.id)")
                    }
                }
            }

            if candidate.isPinned {
                Button("Unpin \(candidate.title)") {
                    onUnpinCandidate()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("unpinCandidateButton.\(candidate.id)")
            } else {
                Button("Pin \(candidate.title)") {
                    onPinCandidate(candidate.candidateID)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("pinCandidateButton.\(candidate.id)")
            }
        }
        .padding(.vertical, 6)
        .accessibilityIdentifier("candidateRow.\(candidate.id)")
    }

    private func badge(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }
}
