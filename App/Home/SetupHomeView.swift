import SwiftUI

struct SetupHomeView: View {
    private let placeholderLink: String
    private let importErrorMessage: String?
    private let isImporting: Bool
    @State private var link: String

    let onImport: (String) -> Void

    init(
        placeholderLink: String,
        importErrorMessage: String?,
        isImporting: Bool,
        onImport: @escaping (String) -> Void
    ) {
        self.placeholderLink = placeholderLink
        self.importErrorMessage = importErrorMessage
        self.isImporting = isImporting
        self.onImport = onImport
        _link = State(initialValue: "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 10) {
                Text("Add your subscription")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("Paste an HTTP(S) subscription link. RockeRoom currently imports Clash YAML and base64 VLESS-style share-link feeds, then lets you run benchmarks from Home.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("setupScreenHeader")

            VStack(alignment: .leading, spacing: 14) {
                Text("Subscription link")
                    .font(.headline)

                TextField("", text: $link, prompt: Text(placeholderLink))
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
                    .accessibilityIdentifier("subscriptionLinkField")

                if let importErrorMessage {
                    Text(importErrorMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("importErrorMessage")
                } else {
                    Text("RockeRoom validates the link, imports supported subscription content, and keeps benchmarking under your control.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if ProcessInfo.processInfo.environment["ROCKEROOM_SHOW_TEST_LINK_PRESETS"] == "1" {
                    HStack(spacing: 10) {
                        Button("Use valid demo link") {
                            link = "https://example.com/subscription"
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("useValidDemoLinkButton")

                        Button("Use invalid demo link") {
                            link = "https://invalid.example.com/subscription"
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("useInvalidDemoLinkButton")
                    }
                }
            }
            .padding(20)
            .background(Color(red: 0.95, green: 0.97, blue: 0.99), in: RoundedRectangle(cornerRadius: 28, style: .continuous))

            Button {
                onImport(resolvedLink)
            } label: {
                HStack {
                    if isImporting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isImporting ? "Importing…" : "Import Subscription")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(resolvedLink.isEmpty || isImporting ? Color.gray.opacity(0.5) : Color.black)
            )
            .disabled(resolvedLink.isEmpty || isImporting)
            .accessibilityIdentifier("importSubscriptionButton")

            Spacer()
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.99, blue: 1.0),
                    Color(red: 0.91, green: 0.95, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }

    private var resolvedLink: String {
        link.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
