import SwiftUI
import SwiftData

@main
struct DaymarkApp: App {
    @AppStorage("appearanceMode") private var appearanceRaw = AppearanceMode.system.rawValue
    @State private var showSplash = true   // resets on every cold launch only

    init() {
        UserDefaults.standard.register(defaults: [
            "animationEnabled": true,
            "hapticEnabled": true,
            "weekStartDay": 0          // 0 = follow system, 1 = Sunday, 2 = Monday, 7 = Saturday
        ])
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                if showSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .preferredColorScheme(AppearanceMode(rawValue: appearanceRaw)?.colorScheme)
        }
        .modelContainer(for: [Goal.self, CheckIn.self, Achievement.self, Reflection.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            StatsView()
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .task { NotificationManager.shared.rescheduleAll(context: context) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { NotificationManager.shared.rescheduleAll(context: context) }
        }
    }
}
