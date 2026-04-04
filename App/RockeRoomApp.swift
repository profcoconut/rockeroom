import SwiftUI

@main
struct RockeRoomApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var autoModeViewModel = AutoModeViewModel()
    @StateObject private var expertConsoleViewModel = ExpertConsoleViewModel()

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
