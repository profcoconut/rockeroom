import SwiftUI

struct MarketplaceView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Marketplace")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text("This tab is a placeholder in v1. RockeRoom’s core loop is import, benchmark, inspect, and control.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Label("No provider catalog yet", systemImage: "shippingbox")
                Label("No direct switching from this tab", systemImage: "arrow.left.arrow.right")
                Label("Use Home and Expert Console for the real workflow", systemImage: "checkmark.circle")
            }
            .font(.footnote)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.95, green: 0.97, blue: 0.99), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.99, green: 0.99, blue: 1.0).ignoresSafeArea())
        .navigationTitle("Marketplace")
        .accessibilityIdentifier("marketplaceScreen")
    }
}
