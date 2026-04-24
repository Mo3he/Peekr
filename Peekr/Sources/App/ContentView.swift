import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Services", systemImage: "square.grid.2x2.fill")
                }

            EventLogTabView()
                .tabItem {
                    Label("Status Log", systemImage: "clock.arrow.circlepath")
                }
        }
    }
}

/// Wrapper so the EventLogView gets its own HomeViewModel that shares the same store data.
private struct EventLogTabView: View {
    @StateObject private var vm = HomeViewModel()

    var body: some View {
        EventLogView(vm: vm)
    }
}
