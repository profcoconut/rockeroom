import SwiftUI
import SharedKit

struct WhyThisView: View {
    let proofPayload: ProofPayload
    let recommendationSummary: String

    var body: some View {
        List {
            Section("Why this") {
                Text(recommendationSummary)
                Text("The same shared snapshot powers Auto Mode, Expert Console, and marketplace evidence.")
                    .foregroundStyle(.secondary)
            }

            Section("Inline proof") {
                if proofPayload.deltas.isEmpty {
                    Text("Run optimize to generate measurable proof.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(proofPayload.deltas.prefix(3))) { delta in
                        Label(formatted(delta), systemImage: delta.isImprovement ? "arrow.up.right" : "arrow.down.right")
                    }
                }
            }
        }
        .navigationTitle("Why this?")
    }

    private func formatted(_ delta: ProofDelta) -> String {
        let diff = delta.candidateValue - delta.currentValue
        let sign = diff > 0 ? "+" : ""
        return "\(delta.metricName.capitalized): \(sign)\(Int(diff.rounded()))\(delta.unit)"
    }
}
