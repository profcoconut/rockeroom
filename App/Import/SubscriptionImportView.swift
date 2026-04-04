import SwiftUI

struct SubscriptionImportView: View {
    private let placeholderLink: String
    @State private var link: String

    let onImport: (String) -> Void
    let onCancel: () -> Void

    init(placeholderLink: String, onImport: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.placeholderLink = placeholderLink
        _link = State(initialValue: "")
        self.onImport = onImport
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Clash subscription link") {
                    TextField("", text: $link, prompt: Text(placeholderLink))
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("subscriptionLinkField")
                }

                if ProcessInfo.processInfo.environment["ROCKEROOM_SHOW_TEST_LINK_PRESETS"] == "1" {
                    Section("Test presets") {
                        Button("Use valid demo link") {
                            link = "https://example.com/subscription"
                        }
                        .accessibilityIdentifier("useValidDemoLinkButton")

                        Button("Use invalid demo link") {
                            link = "https://invalid.example.com/subscription"
                        }
                        .accessibilityIdentifier("useInvalidDemoLinkButton")
                    }
                }

                Section {
                    Text("RockeRoom imports a Clash subscription link, validates the fetched content, then normalizes it into the alpha foundation model.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Import")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onImport(link)
                    }
                    .accessibilityIdentifier("importSubscriptionButton")
                }
            }
        }
    }
}
