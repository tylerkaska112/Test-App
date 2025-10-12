import SwiftUI

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // App Icon and Header
                    VStack(spacing: 12) {
                        Image("AppIcon")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        Text("SafelyRouted")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Version 3.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Description
                    Text("SafelyRouted helps you navigate your travels with real-time safety alerts, route planning, and community-driven updates. Stay informed and make smarter, safer travel decisions, wherever you go.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Features Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.headline)
                        
                        FeatureRow(icon: "map.fill", title: "Real-time Navigation", description: "Live routing with current conditions")
                        FeatureRow(icon: "shield.fill", title: "Safe Route Planning", description: "Customizable safety preferences")
                        FeatureRow(icon: "person.3.fill", title: "Community Updates", description: "Real-time feedback from users")
                        FeatureRow(icon: "arrow.down.circle.fill", title: "Offline Access", description: "Save routes for offline use")
                        FeatureRow(icon: "lock.fill", title: "Privacy First", description: "No tracking, your data stays yours")
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        ActionButton(icon: "star.fill", title: "Rate SafelyRouted", color: .orange) {
                            rateApp()
                        }
                        
                        ActionButton(icon: "square.and.arrow.up", title: "Share with Friends", color: .blue) {
                            shareApp()
                        }
                        
                        ActionButton(icon: "envelope.fill", title: "Contact Support", color: .green) {
                            contactSupport()
                        }
                        
                        ActionButton(icon: "doc.text.fill", title: "Privacy Policy", color: .purple) {
                            openPrivacyPolicy()
                        }
                        
                        ActionButton(icon: "doc.plaintext.fill", title: "Terms of Service", color: .gray) {
                            openTermsOfService()
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Acknowledgments
                    VStack(spacing: 8) {
                        Text("Acknowledgments")
                            .font(.headline)
                        
                        Text("Built with care for safer travels")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Special thanks to our community contributors")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Footer
                    VStack(spacing: 4) {
                        Text("© 2025 Tyler Kaska")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        Text("SafelyRouted")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func rateApp() {
        // Replace with your actual App Store ID
        if let url = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID?action=write-review") {
            openURL(url)
        }
    }
    
    private func shareApp() {
        guard let url = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID") else { return }
        let activityVC = UIActivityViewController(
            activityItems: ["Check out SafelyRouted - Navigate safely with real-time alerts!", url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func contactSupport() {
        if let url = URL(string: "mailto:support@safelyrouted.com?subject=SafelyRouted%20Support") {
            openURL(url)
        }
    }
    
    private func openPrivacyPolicy() {
        if let url = URL(string: "https://www.safelyrouted.com/privacy") {
            openURL(url)
        }
    }
    
    private func openTermsOfService() {
        if let url = URL(string: "https://www.safelyrouted.com/terms") {
            openURL(url)
        }
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

struct InfoView_Previews: PreviewProvider {
    static var previews: some View {
        InfoView()
    }
}
