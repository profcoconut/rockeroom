import SwiftUI

struct MainTabView: View {
    @Binding var selectedTab: MainTab
    @ObservedObject var autoModeViewModel: AutoModeViewModel
    @ObservedObject var expertConsoleViewModel: ExpertConsoleViewModel

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(viewModel: autoModeViewModel)
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(MainTab.home)

            NavigationStack {
                ExpertConsoleView(
                    viewModel: expertConsoleViewModel,
                    onPinCandidate: { candidateID in
                        Task {
                            await autoModeViewModel.pin(candidateID: candidateID)
                        }
                    },
                    onUnpinCandidate: {
                        Task {
                            await autoModeViewModel.unpinCurrentProvider()
                        }
                    }
                )
            }
            .tabItem {
                Label("Expert Console", systemImage: "slider.horizontal.3")
            }
            .tag(MainTab.expertConsole)

            NavigationStack {
                MarketplaceView()
            }
            .tabItem {
                Label("Marketplace", systemImage: "bag")
            }
            .tag(MainTab.marketplace)
        }
    }
}
