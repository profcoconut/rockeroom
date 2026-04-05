import SwiftUI
import SharedKit

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
        let dataStore = UserDefaultsDataStore()
        let snapshotStore = ResultSnapshotStore(store: dataStore)
        let subscriptionRepository = SubscriptionRepository(store: dataStore)
        let tunnelSessionStore = TunnelSessionStore(store: dataStore)
        let pinStateStore = PinStateStore(store: dataStore)
        let destinationAssignmentStore = DestinationRoutingAssignmentStore(store: dataStore)

        return AutoModeViewModel(
            runtimeProfile: makeStandardRuntimeProfile(tunnelSessionStore: tunnelSessionStore),
            manualDebugRuntimeProfile: makeManualDebugRuntimeProfile(tunnelSessionStore: tunnelSessionStore),
            snapshotStore: snapshotStore,
            subscriptionRepository: subscriptionRepository,
            tunnelSessionStore: tunnelSessionStore,
            pinStateStore: pinStateStore,
            destinationAssignmentStore: destinationAssignmentStore,
            now: resolvedNow
        )
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

    private static func makeStandardRuntimeProfile(
        tunnelSessionStore: TunnelSessionStore
    ) -> AutoModeRuntimeProfile {
        let environment = ProcessInfo.processInfo.environment
        let mode: AutoModeRuntimeMode = environment["ROCKEROOM_LIVE_E2E_SCENARIO"] == nil &&
            environment["ROCKEROOM_USE_DEMO_TUNNEL"] != "1" &&
            environment["ROCKEROOM_USE_DEMO_FETCHER"] != "1"
            ? .standard
            : .launchDrivenE2E

        let importer: ClashSubscriptionImporter
        if environment["ROCKEROOM_USE_DEMO_FETCHER"] == "1" {
            importer = ClashSubscriptionImporter(fetcher: LocalDevelopmentSubscriptionFetcher())
        } else {
            importer = ClashSubscriptionImporter()
        }

        let adapter: ClashAdapter
        if environment["ROCKEROOM_USE_DEMO_TUNNEL"] == "1" {
            let manager: any TunnelManaging
            if environment["ROCKEROOM_DEMO_TUNNEL_FAILURE"] == "1" {
                manager = FailingTunnelManager()
            } else {
                manager = InMemoryTunnelManager()
            }
            adapter = ClashAdapter(
                engine: TunnelManagerClashEngine(
                    tunnelManager: manager,
                    sessionStore: tunnelSessionStore
                )
            )
        } else {
            adapter = ClashAdapter(sessionStore: tunnelSessionStore)
        }

        return AutoModeRuntimeProfile(
            mode: mode,
            importer: importer,
            adapter: adapter,
            runner: ProbeRunner(executor: DemoProbeExecutor())
        )
    }

    private static func makeManualDebugRuntimeProfile(
        tunnelSessionStore: TunnelSessionStore
    ) -> AutoModeRuntimeProfile {
        AutoModeRuntimeProfile(
            mode: .manualDebug,
            importer: ClashSubscriptionImporter(),
            adapter: ClashAdapter(
                engine: TunnelManagerClashEngine(
                    tunnelManager: InMemoryTunnelManager(),
                    sessionStore: tunnelSessionStore
                )
            ),
            runner: ProbeRunner(executor: DemoProbeExecutor())
        )
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
