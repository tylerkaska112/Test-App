import SwiftUI

struct WelcomeBackBanner: View {
    @AppStorage("userFirstName") private var userFirstName: String = ""
    @State private var showBanner = true
    var duration: Double = 3.0

    var body: some View {
        VStack {
            if showBanner {
                Text("Welcome back to my app \(userFirstName.isEmpty ? "friend" : userFirstName)")
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .background(Color.accentColor.opacity(0.98))
                    .cornerRadius(12)
                    .shadow(radius: 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 16)
                    .padding(.horizontal)
            }
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.45)) {
                showBanner = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                withAnimation(.easeInOut(duration: 0.65)) {
                    showBanner = false
                }
            }
        }
    }
}

#Preview {
    WelcomeBackBanner()
}
