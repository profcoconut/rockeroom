import SwiftUI
import SharedKit

struct AppRootView: View {
    @State private var showingImportSheet = false
    @State private var navigationPath = NavigationPath()
    @ObservedObject var autoModeViewModel: AutoModeViewModel
    @ObservedObject var expertConsoleViewModel: ExpertConsoleViewModel

    var body: some View {
        NavigationStack(path: $navigationPath) {
            AutoModeView(
                viewModel: autoModeViewModel,
                onImportClashSubscription: {
                    showingImportSheet = true
                },
                onOpenWhyThis: {
                    navigationPath.append(AppDestination.whyThis)
                },
                onOpenExpertConsole: {
                    expertConsoleViewModel.refresh(
                        snapshot: autoModeViewModel.snapshot,
                        recommendationState: autoModeViewModel.recommendationState,
                        pinState: autoModeViewModel.pinState
                    )
                    navigationPath.append(AppDestination.expertConsole)
                },
                onOpenMarketplace: {
                    navigationPath.append(AppDestination.marketplace)
                },
                marketplaceProjection: marketplaceProjection
            )
            .navigationTitle("RockeRoom")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .expertConsole:
                    ExpertConsoleView(
                        viewModel: expertConsoleViewModel,
                        onPinCandidate: { candidateID in
                            Task {
                                await autoModeViewModel.pin(candidateID: candidateID)
                                syncExpertConsole()
                            }
                        },
                        onUnpinCandidate: {
                            Task {
                                await autoModeViewModel.unpinCurrentProvider()
                                syncExpertConsole()
                            }
                        }
                    )
                case .whyThis:
                    WhyThisView(
                        proofPayload: autoModeViewModel.currentProofPayload,
                        recommendationSummary: autoModeViewModel.recommendationSummaryText
                    )
                case .marketplace:
                    MarketplaceView(projection: marketplaceProjection)
                }
            }
            .sheet(isPresented: $showingImportSheet) {
                SubscriptionImportView(
                    placeholderLink: autoModeViewModel.subscriptionLink,
                    onImport: { link in
                        autoModeViewModel.importSubscriptionLink(link)
                        showingImportSheet = false
                    },
                    onCancel: {
                        showingImportSheet = false
                    }
                )
            }
            .onAppear {
                syncExpertConsole()
            }
            .onChange(of: autoModeViewModel.snapshot) { _, _ in
                syncExpertConsole()
            }
            .onChange(of: autoModeViewModel.recommendationState) { _, _ in
                syncExpertConsole()
            }
            .onChange(of: autoModeViewModel.pinState) { _, _ in
                syncExpertConsole()
            }
        }
    }

    private func syncExpertConsole() {
        expertConsoleViewModel.refresh(
            snapshot: autoModeViewModel.snapshot,
            recommendationState: autoModeViewModel.recommendationState,
            pinState: autoModeViewModel.pinState
        )
    }

    private var marketplaceProjection: EvidenceProjection {
        EvidenceProjection.project(
            snapshot: autoModeViewModel.snapshot,
            recommendationState: autoModeViewModel.recommendationState,
            pinState: autoModeViewModel.pinState
        )
    }
}

enum AppDestination: Hashable {
    case expertConsole
    case whyThis
    case marketplace
}
