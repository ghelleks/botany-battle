import SwiftUI

struct ErrorView: View {
    let error: AppError
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Error Icon
                Image(systemName: errorIcon)
                    .font(.system(size: 60))
                    .foregroundColor(errorColor)
                
                // Error Title
                Text(errorTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                // Error Description
                Text(error.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Action Buttons
                VStack(spacing: 12) {
                    if error.category == .network {
                        Button("Try Again") {
                            // Trigger retry logic
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Button("Continue") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Oops!")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var errorIcon: String {
        switch error.category {
        case .network:
            return "wifi.exclamationmark"
        case .data:
            return "externaldrive.badge.exclamationmark"
        case .game:
            return "gamecontroller.fill"
        case .user:
            return "person.crop.circle.badge.exclamationmark"
        case .system:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var errorColor: Color {
        switch error.severity {
        case .low:
            return .orange
        case .moderate:
            return .orange
        case .high:
            return .red
        case .critical:
            return .red
        }
    }
    
    private var errorTitle: String {
        switch error.category {
        case .network:
            return "Connection Problem"
        case .data:
            return "Data Issue"
        case .game:
            return "Game Error"
        case .user:
            return "Account Issue"
        case .system:
            return "Something Went Wrong"
        }
    }
}

#Preview {
    ErrorView(error: AppError(
        code: "preview_error",
        category: .network,
        severity: .moderate,
        context: .gamePlay,
        description: "Unable to connect to the internet. Please check your connection and try again."
    ))
}