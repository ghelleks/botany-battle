import SwiftUI
import ComposableArchitecture

struct ContentView: View {
    let store: StoreOf<AppFeature>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Group {
                if viewStore.isAuthenticated {
                    MainTabView(store: store)
                } else {
                    AuthenticationView(
                        store: store.scope(state: \.auth, action: \.auth)
                    )
                }
            }
        }
    }
}

#Preview {
    ContentView(
        store: Store(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        )
    )
}