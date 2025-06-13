import SwiftUI
import ComposableArchitecture

struct MainTabView: View {
    @Bindable var store: StoreOf<AppFeature>
    
    var body: some View {
        TabView(selection: Binding(
            get: { store.currentTab },
            set: { store.send(.tabChanged($0)) }
        )) {
            GameView(store: store.scope(state: \.game, action: \.game))
                .tabItem {
                    Image(systemName: "gamecontroller.fill")
                    Text("Game")
                }
                .tag(AppFeature.State.Tab.game)
            
            ProfileView(store: store.scope(state: \.profile, action: \.profile))
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(AppFeature.State.Tab.profile)
            
            ShopView(store: store.scope(state: \.shop, action: \.shop))
                .tabItem {
                    Image(systemName: "bag.fill")
                    Text("Shop")
                }
                .tag(AppFeature.State.Tab.shop)
        }
        .accentColor(.botanicalGreen)
        .onAppear {
            store.send(.onAppear)
        }
    }
}

struct GameView: View {
    let store: StoreOf<GameFeature>
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Game View")
                    .botanicalStyle(BotanicalTextStyle.largeTitle)
                Text("Plant identification battles")
                    .botanicalStyle(BotanicalTextStyle.subheadline)
                
                Spacer()
                
                BotanicalButton("Find Game", style: .primary, size: .large) {
                    store.send(.searchForGame(.medium))
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Botany Battle")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ProfileView: View {
    let store: StoreOf<ProfileFeature>
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Profile View")
                    .botanicalStyle(BotanicalTextStyle.largeTitle)
                Text("Your stats and achievements")
                    .botanicalStyle(BotanicalTextStyle.subheadline)
                
                Spacer()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            store.send(.loadProfile)
        }
    }
}

struct ShopView: View {
    let store: StoreOf<ShopFeature>
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Shop View")
                    .botanicalStyle(BotanicalTextStyle.largeTitle)
                Text("Power-ups and customizations")
                    .botanicalStyle(BotanicalTextStyle.subheadline)
                
                Spacer()
            }
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            store.send(.loadShopItems)
        }
    }
}

#Preview {
    MainTabView(
        store: Store(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        )
    )
}