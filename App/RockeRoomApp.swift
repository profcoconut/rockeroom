import SwiftUI

@main
struct RockeRoomApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var autoModeViewModel: AutoModeViewModel
    @StateObject private var expertConsoleViewModel: ExpertConsoleViewModel
    @StateObject private var liveE2ERunner: LiveE2ERunner

    init() {
        _autoModeViewModel = StateObject(wrappedValue: AppEnvironment.makeAutoModeViewModel())
        _expertConsoleViewModel = StateObject(wrappedValue: ExpertConsoleViewModel())
        _liveE2ERunner = StateObject(wrappedValue: LiveE2ERunner())
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                autoModeViewModel: autoModeViewModel,
                expertConsoleViewModel: expertConsoleViewModel,
                liveE2ERunner: liveE2ERunner
            )
            .task {
                await autoModeViewModel.resetStoredStateIfNeeded()
                await seedScenarioState(into: autoModeViewModel)
                await autoModeViewModel.restoreState()
                expertConsoleViewModel.refresh(
                    snapshot: autoModeViewModel.snapshot,
                    recommendationState: autoModeViewModel.recommendationState,
                    pinState: autoModeViewModel.pinState
                )
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await autoModeViewModel.handleAppDidBecomeActive()
                    expertConsoleViewModel.refresh(
                        snapshot: autoModeViewModel.snapshot,
                        recommendationState: autoModeViewModel.recommendationState,
                        pinState: autoModeViewModel.pinState
                    )
                }
            }
        }
    }
}

private enum AppEnvironment {
    @MainActor
    static func makeAutoModeViewModel() -> AutoModeViewModel {
        AutoModeViewModel(now: resolvedNow)
    }

    private static var resolvedNow: @Sendable () -> Date {
        let environment = ProcessInfo.processInfo.environment
        guard
            let unixTimestamp = environment["ROCKEROOM_NOW_UNIX"],
            let seconds = Double(unixTimestamp)
        else {
            return Date.init
        }

        return { Date(timeIntervalSince1970: seconds) }
    }
}

/// Seeds state from the resolved E2E scenario into the AutoModeViewModel.
///
/// This is called between resetStoredStateIfNeeded() and restoreState() so that
/// scenario-seeded state is present in the stores before restore loads it.
private func seedScenarioState(into viewModel: AutoModeViewModel) async {
    guard let scenario = LiveE2EScenario.resolved() else { return }
    if let assignment = scenario.destinationAssignment {
        await viewModel.seedDestinationAssignment(assignment)
    }
}
