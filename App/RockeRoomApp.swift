import SwiftUI

@main
struct RockeRoomApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var autoModeViewModel: AutoModeViewModel
    @StateObject private var expertConsoleViewModel: ExpertConsoleViewModel

    init() {
        _autoModeViewModel = StateObject(wrappedValue: AppEnvironment.makeAutoModeViewModel())
        _expertConsoleViewModel = StateObject(wrappedValue: ExpertConsoleViewModel())
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                autoModeViewModel: autoModeViewModel,
                expertConsoleViewModel: expertConsoleViewModel
            )
            .task {
                await autoModeViewModel.resetStoredStateIfNeeded()
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
