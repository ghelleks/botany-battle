import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: MainTab = .game
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Game Tab
            NavigationStack {
                GameModeSelectionView()
                    .environmentObject(appState.gameFeature)
            }
            .tabItem {
                Label("Game", systemImage: "gamecontroller.fill")
            }
            .tag(MainTab.game)
            
            // Profile Tab
            NavigationStack {
                ProfileView()
                    .environmentObject(appState.profileFeature)
                    .environmentObject(appState.authFeature)
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag(MainTab.profile)
            
            // Shop Tab
            NavigationStack {
                ShopView()
                    .environmentObject(appState.shopFeature)
            }
            .tabItem {
                Label("Shop", systemImage: "bag.fill")
            }
            .tag(MainTab.shop)
            
            // Settings Tab
            NavigationStack {
                SettingsView()
                    .environmentObject(appState.settingsFeature)
                    .environmentObject(appState.authFeature)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(MainTab.settings)
        }
        .accentColor(.green)
        .overlay(alignment: .top) {
            if appState.isOfflineMode {
                OfflineStatusBar()
            }
        }
    }
}

// MARK: - Supporting Views

struct OfflineStatusBar: View {
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(.orange)
            Text("Playing Offline")
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.orange.opacity(0.1))
        .clipShape(Capsule())
        .padding(.top, 8)
    }
}

// MARK: - Tab Definition

enum MainTab: String, CaseIterable {
    case game = "game"
    case profile = "profile"
    case shop = "shop"
    case settings = "settings"
    
    var title: String {
        switch self {
        case .game:
            return "Game"
        case .profile:
            return "Profile"
        case .shop:
            return "Shop"
        case .settings:
            return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .game:
            return "gamecontroller.fill"
        case .profile:
            return "person.fill"
        case .shop:
            return "bag.fill"
        case .settings:
            return "gearshape.fill"
        }
    }
}

// MARK: - Removed placeholder views - now using dedicated feature modules from Sprint 3

// MARK: - Helper Views

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 24)
            
            Text(title)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
}