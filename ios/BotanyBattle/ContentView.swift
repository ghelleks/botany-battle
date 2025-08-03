import SwiftUI
import GameKit

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

struct SplashScreenView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("Botany Battle")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Test your botanical knowledge")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            ProgressView()
                .scaleEffect(1.2)
                .tint(.green)
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}