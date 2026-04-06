import SwiftUI

struct AppRootView: View {
    @State private var selectedTab: MainTab = .home
    @State private var showsDebugTools = false
    @State private var debugLiveImportLink = ""
    @ObservedObject var autoModeViewModel: AutoModeViewModel
    @ObservedObject var expertConsoleViewModel: ExpertConsoleViewModel
    let liveE2ERunner: LiveE2ERunner?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            primaryContent
            #if DEBUG
            if showsDebugTools {
                debugBackdrop
                debugPanel
            }
            debugButton
            #endif
        }
        .onAppear {
            syncExpertConsole()
            advanceLiveE2E()
        }
        .onChange(of: autoModeViewModel.snapshot) { _, _ in
            syncExpertConsole()
            advanceLiveE2E()
        }
        .onChange(of: autoModeViewModel.recommendationState) { _, _ in
            syncExpertConsole()
            advanceLiveE2E()
        }
        .onChange(of: autoModeViewModel.pinState) { _, _ in
            syncExpertConsole()
            advanceLiveE2E()
        }
        .onChange(of: autoModeViewModel.status) { _, _ in
            advanceLiveE2E()
        }
        .onChange(of: autoModeViewModel.hasRestoredSession) { _, _ in
            advanceLiveE2E()
        }
        .onChange(of: autoModeViewModel.hasImportedSubscription) { _, hasImportedSubscription in
            if hasImportedSubscription {
                selectedTab = .home
            }
            advanceLiveE2E()
        }
        .onChange(of: selectedTab) { _, _ in
            advanceLiveE2E()
        }
        .onChange(of: expertConsoleViewModel.rankedCandidates) { _, _ in
            advanceLiveE2E()
        }
        .onChange(of: autoModeViewModel.refreshHintText) { _, _ in
            advanceLiveE2E()
        }
    }

    @ViewBuilder
    private var primaryContent: some View {
        if autoModeViewModel.hasImportedSubscription {
            MainTabView(
                selectedTab: $selectedTab,
                autoModeViewModel: autoModeViewModel,
                expertConsoleViewModel: expertConsoleViewModel
            )
        } else {
            SetupHomeView(
                placeholderLink: autoModeViewModel.subscriptionLink,
                importErrorMessage: autoModeViewModel.importErrorMessage,
                isImporting: autoModeViewModel.status == .importing,
                onImport: { link in
                    autoModeViewModel.importSubscriptionLink(link)
                }
            )
        }
    }

    private func syncExpertConsole() {
        expertConsoleViewModel.refresh(
            snapshot: autoModeViewModel.snapshot,
            recommendationState: autoModeViewModel.recommendationState,
            pinState: autoModeViewModel.pinState,
            destinationAssignments: autoModeViewModel.destinationAssignment,
            monitoringStatusText: autoModeViewModel.monitoringStatusText
        )
    }

    #if DEBUG
    private var debugButton: some View {
        Button {
            debugLiveImportLink = resolvedDebugImportLink
            showsDebugTools = true
        } label: {
            Text("Debug")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.trailing, 20)
        .padding(.bottom, 28)
        .accessibilityIdentifier("debugOverlayButton")
    }

    private var debugBackdrop: some View {
        Color.black.opacity(0.18)
            .ignoresSafeArea()
            .accessibilityIdentifier("debugToolsBackdrop")
            .onTapGesture {
                showsDebugTools = false
            }
    }

    private var debugPanel: some View {
        DebugToolsPanel(
            onReset: {
                showsDebugTools = false
                Task {
                    await autoModeViewModel.resetDebugState()
                    selectedTab = .home
                    syncExpertConsole()
                }
            },
            liveImportLink: $debugLiveImportLink,
            onClose: {
                showsDebugTools = false
            },
            onImportDeterministicDemo: {
                showsDebugTools = false
                Task {
                    await autoModeViewModel.importDebugSource(.deterministicDemo)
                    selectedTab = .home
                    syncExpertConsole()
                }
            },
            onImportLiveURL: {
                let liveURL = debugLiveImportLink
                showsDebugTools = false
                Task {
                    await autoModeViewModel.importDebugSource(.liveURL(liveURL))
                    selectedTab = .home
                    syncExpertConsole()
                }
            }
        )
        .zIndex(1)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .accessibilityIdentifier("debugToolsPanel")
    }
    #endif

    private var resolvedDebugImportLink: String {
        let trimmed = autoModeViewModel.subscriptionLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmed.isEmpty,
            let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme)
        else {
            return ""
        }
        return trimmed
    }

    private func advanceLiveE2E() {
        liveE2ERunner?.advance(
            state: LiveE2ERunner.State(
                hasRestoredSession: autoModeViewModel.hasRestoredSession,
                hasImportedSubscription: autoModeViewModel.hasImportedSubscription,
                importErrorMessage: autoModeViewModel.importErrorMessage,
                isImporting: autoModeViewModel.status == .importing,
                hasBenchmarkResults: autoModeViewModel.hasBenchmarkResults,
                isBenchmarkInFlight: autoModeViewModel.isBenchmarkInFlight,
                selectedTab: selectedTab,
                refreshHintText: autoModeViewModel.refreshHintText,
                pinnedCandidateID: autoModeViewModel.pinState.candidateID,
                rankedCandidates: expertConsoleViewModel.rankedCandidates.map {
                    .init(candidateID: $0.candidateID, title: $0.title)
                }
            ),
            actions: LiveE2ERunner.Actions(
                importSubscription: { link in
                    autoModeViewModel.importSubscriptionLink(link)
                },
                runBenchmark: {
                    autoModeViewModel.optimize()
                },
                selectTab: { tab in
                    selectedTab = tab
                },
                pinCandidate: { candidateID in
                    Task {
                        await autoModeViewModel.pin(candidateID: candidateID)
                    }
                },
                unpinCandidate: {
                    Task {
                        await autoModeViewModel.unpinCurrentProvider()
                    }
                }
            )
        )
    }
}

enum MainTab: Hashable {
    case home
    case expertConsole
    case marketplace
}

#if DEBUG
private struct DebugToolsPanel: View {
    let onReset: () -> Void
    @Binding var liveImportLink: String
    let onClose: () -> Void
    let onImportDeterministicDemo: () -> Void
    let onImportLiveURL: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Debug Tools")
                        .font(.headline)
                    Spacer()
                    Button("Close", action: onClose)
                        .accessibilityIdentifier("debugToolsCloseButton")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Live URL")
                        .font(.subheadline.weight(.semibold))
                    Text("Imports the URL and switches this app session to a simulator-safe benchmark runtime so Run Benchmark works like a normal manual flow.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("https://provider.example.com/subscription", text: $liveImportLink)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("debugLiveImportLinkField")

                    Button("Import typed URL", action: onImportLiveURL)
                        .disabled(liveImportLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("debugImportTypedURLButton")
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Deterministic Import")
                        .font(.subheadline.weight(.semibold))
                    actionButton("Import demo subscription", action: onImportDeterministicDemo)
                    Text("Imports a built-in demo subscription and switches this app session to the same simulator-safe benchmark runtime. You still tap Run Benchmark yourself.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Reset")
                        .font(.subheadline.weight(.semibold))
                    actionButton("Reset app", action: onReset)
                }

                Text("Debug starts a simulator-safe manual test session. Import, Home, Run Benchmark, Expert Console, pinning, and refresh still use the normal product flow, while explicit true tunnel IPC validation remains a separate path.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .frame(maxWidth: 360, maxHeight: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
        .padding(.horizontal, 20)
        .padding(.bottom, 100)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
    }
}
#endif
