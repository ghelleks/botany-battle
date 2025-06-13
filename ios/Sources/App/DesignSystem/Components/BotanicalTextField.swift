import SwiftUI

struct BotanicalTextField: View {
    private let title: String
    private let text: Binding<String>
    private let isSecure: Bool
    private let placeholder: String?
    
    init(
        _ title: String,
        text: Binding<String>,
        isSecure: Bool = false,
        placeholder: String? = nil
    ) {
        self.title = title
        self.text = text
        self.isSecure = isSecure
        self.placeholder = placeholder
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundColor(.botanicalDarkGreen)
            
            Group {
                if isSecure {
                    SecureField(placeholder ?? title, text: text)
                } else {
                    TextField(placeholder ?? title, text: text)
                }
            }
            .textFieldStyle(BotanicalTextFieldStyle())
        }
    }
}

struct BotanicalTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.botanicalLightGreen.opacity(0.2))
                    .stroke(Color.botanicalGreen.opacity(0.3), lineWidth: 1)
            )
            .font(.system(.body, design: .rounded))
            .foregroundColor(.textPrimary)
    }
}

#Preview {
    VStack(spacing: 16) {
        BotanicalTextField("Username", text: .constant(""))
        BotanicalTextField("Password", text: .constant(""), isSecure: true)
    }
    .padding()
}