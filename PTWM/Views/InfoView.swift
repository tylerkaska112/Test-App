import SwiftUI

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    descriptionSection
                    featuresSection
                    actionsSection
                    acknowledgmentsSection
                    footerSection
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image("AppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            
            Text("SafelyRouted")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Version 3.0")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }
    
    private var descriptionSection: some View {
        Text("SafelyRouted helps you navigate your travels with real-time safety alerts, route planning, and community-driven updates. Stay informed and make smarter, safer travel decisions, wherever you go.")
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Features")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal, 24)
            
            VStack(spacing: 12) {
                FeatureRow(
                    icon: "map.fill",
                    title: "Real-time Navigation",
                    description: "Live routing with current conditions",
                    color: .blue
                )
                
                FeatureRow(
                    icon: "shield.fill",
                    title: "Safe Route Planning",
                    description: "Customizable safety preferences",
                    color: .green
                )
                
                FeatureRow(
                    icon: "person.3.fill",
                    title: "Community Updates",
                    description: "Real-time feedback from users",
                    color: .orange
                )
                
                FeatureRow(
                    icon: "arrow.down.circle.fill",
                    title: "Offline Access",
                    description: "Save routes for offline use",
                    color: .purple
                )
                
                FeatureRow(
                    icon: "lock.fill",
                    title: "Privacy First",
                    description: "No tracking, your data stays yours",
                    color: .red
                )
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            ActionButton(
                icon: "star.fill",
                title: "Rate SafelyRouted",
                color: .orange,
                action: rateApp
            )
            
            ActionButton(
                icon: "square.and.arrow.up",
                title: "Share with Friends",
                color: .blue,
                action: shareApp
            )
            
            ActionButton(
                icon: "envelope.fill",
                title: "Contact Support",
                color: .green,
                action: contactSupport
            )
            
            ActionButton(
                icon: "doc.text.fill",
                title: "Privacy Policy",
                color: .purple,
                action: openPrivacyPolicy
            )
            
            ActionButton(
                icon: "doc.plaintext.fill",
                title: "Terms of Service",
                color: .gray,
                action: openTermsOfService
            )
        }
        .padding(.horizontal, 24)
    }
    
    private var acknowledgmentsSection: some View {
        VStack(spacing: 8) {
            Text("Acknowledgments")
                .font(.headline)
            
            Text("Built with care for safer travels")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Special thanks to our community contributors")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }
    
    private var footerSection: some View {
        VStack(spacing: 4) {
            Text("© 2025 Tyler Kaska")
                .font(.footnote)
                .foregroundStyle(.secondary)
            
            Text("SafelyRouted")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Actions
    
    private func rateApp() {
        // Replace YOUR_APP_ID with your actual App Store ID
        guard let url = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID?action=write-review") else {
            return
        }
        openURL(url)
    }
    
    private func shareApp() {
        guard let url = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID") else {
            return
        }
        
        let shareText = "Check out SafelyRouted - Navigate safely with real-time alerts!"
        let activityVC = UIActivityViewController(
            activityItems: [shareText, url],
            applicationActivities: nil
        )
        
        // For iPad support
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func contactSupport() {
        guard let url = URL(string: "mailto:support@safelyrouted.com?subject=SafelyRouted%20Support") else {
            return
        }
        openURL(url)
    }
    
    private func openPrivacyPolicy() {
        guard let url = URL(string: "https://www.safelyrouted.com/privacy") else {
            return
        }
        openURL(url)
    }
    
    private func openTermsOfService() {
        guard let url = URL(string: "https://www.safelyrouted.com/terms") else {
            return
        }
        openURL(url)
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    var color: Color = .accentColor
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 28)
                
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    InfoView()
}
