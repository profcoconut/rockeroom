import SwiftUI

struct AppRootView: View {
    @State private var selectedTab: MainTab = .home
    @ObservedObject var autoModeViewModel: AutoModeViewModel
    @ObservedObject var expertConsoleViewModel: ExpertConsoleViewModel
    let liveE2ERunner: LiveE2ERunner?

    var body: some View {
        Group {
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

    private func syncExpertConsole() {
        expertConsoleViewModel.refresh(
            snapshot: autoModeViewModel.snapshot,
            recommendationState: autoModeViewModel.recommendationState,
            pinState: autoModeViewModel.pinState
        )
    }

    private func advanceLiveE2E() {
        liveE2ERunner?.advance(
            state: LiveE2ERunner.State(
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
