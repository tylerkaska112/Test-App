import SwiftUI

struct VoiceDownloadInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingTroubleshooting = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Quick Action Button
                    Button {
                        openVoiceSettings()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Go to Voice Settings")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.bottom, 8)

                    // Main Instructions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How to Download New Voices")
                            .font(.title2)
                            .bold()

                        Text("To add new or enhanced voices for navigation, follow these steps:")
                            .font(.body)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 12) {
                            InstructionStep(number: 1, text: "Open the **Settings** app on your device")
                            InstructionStep(number: 2, text: "Tap **Accessibility** → **VoiceOver** → **Speech**")
                            InstructionStep(number: 3, text: "Tap **Add New Language** or select an existing language")
                            InstructionStep(number: 4, text: "Choose a voice and tap the **download icon** (⬇︎)")
                            InstructionStep(number: 5, text: "Wait for the download to complete")
                        }
                    }

                    // Voice Quality Recommendations
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Recommended Voice Types")
                                .font(.headline)
                        }
                        
                        VoiceTypeCard(
                            title: "Premium Voices",
                            description: "Highest quality with natural intonation and pronunciation",
                            icon: "crown.fill",
                            color: .purple
                        )
                        
                        VoiceTypeCard(
                            title: "Enhanced Voices",
                            description: "High quality with improved clarity and naturalness",
                            icon: "waveform",
                            color: .blue
                        )
                        
                        VoiceTypeCard(
                            title: "Standard Voices",
                            description: "Basic quality, smaller file size",
                            icon: "speaker.wave.2",
                            color: .gray
                        )
                    }
                    .padding(.vertical, 8)

                    // Important Notes
                    VStack(alignment: .leading, spacing: 12) {
                        InfoBox(
                            icon: "clock",
                            text: "Downloaded voices may take a few minutes to appear. Restart the app if needed.",
                            color: .blue
                        )
                        
                        InfoBox(
                            icon: "wifi",
                            text: "Voice downloads require an internet connection and may use cellular data if Wi-Fi is unavailable.",
                            color: .orange
                        )
                        
                        InfoBox(
                            icon: "internaldrive",
                            text: "Premium voices can be 200-500 MB. Ensure you have sufficient storage space.",
                            color: .green
                        )
                    }

                    // Troubleshooting Section
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            showingTroubleshooting.toggle()
                        } label: {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                Text("Troubleshooting")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: showingTroubleshooting ? "chevron.up" : "chevron.down")
                            }
                            .foregroundColor(.primary)
                        }
                        
                        if showingTroubleshooting {
                            VStack(alignment: .leading, spacing: 8) {
                                TroubleshootingItem(
                                    problem: "Voice not appearing?",
                                    solution: "Force quit and restart the app, or restart your device"
                                )
                                TroubleshootingItem(
                                    problem: "Download failed?",
                                    solution: "Check your internet connection and available storage space"
                                )
                                TroubleshootingItem(
                                    problem: "Can't find voice settings?",
                                    solution: "Make sure you're running iOS 14 or later"
                                )
                                TroubleshootingItem(
                                    problem: "Voice sounds robotic?",
                                    solution: "Try downloading an Enhanced or Premium voice for better quality"
                                )
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 8)

                    // Additional Help
                    Link(destination: URL(string: "https://support.apple.com/guide/iphone/change-siri-settings-iph6b8f2c34/ios")!) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                            Text("Learn more about iOS voices")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Voice Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func openVoiceSettings() {
        let url = URL(string: "App-prefs:root=ACCESSIBILITY&path=VoiceOver/SPEECH")
        if let url = url, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let fallback = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(fallback)
        }
    }
}

// MARK: - Supporting Views

struct InstructionStep: View {
    let number: Int
    let text: LocalizedStringKey
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor))
            
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

struct VoiceTypeCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

struct InfoBox: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(text)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(uiColor: .systemGray6))
        )
    }
}

struct TroubleshootingItem: View {
    let problem: String
    let solution: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(problem)
                .font(.subheadline)
                .bold()
            Text(solution)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VoiceDownloadInfoView()
}
