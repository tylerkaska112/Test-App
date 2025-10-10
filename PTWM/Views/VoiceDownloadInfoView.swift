import SwiftUI

struct VoiceDownloadInfoView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Button {
                        let url = URL(string: "App-prefs:root=ACCESSIBILITY&path=VoiceOver/SPEECH")
                        if let url = url, UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        } else if let fallback = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(fallback)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "gearshape")
                            Text("Open Settings")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .center)

                    Text("How to Download New Voices")
                        .font(.title2)
                        .bold()
                        .padding(.top, 8)

                    Text("To add new or enhanced voices for navigation, follow these steps:")
                        .font(.body)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Open the **Settings** app on your device.")
                        Text("2. Tap **Accessibility** > **VoiceOver** > **SPEECH** > **Primary Voices** > **Voice**.")
                        Text("3. Choose your desired language (e.g., English).")
                        Text("4. Tap a voice you would like to add, then tap the **Download** button next to it. **Enhanced and Premium Voices are the best options that I could reccomend.**")
                        Text("5. The new voice will be available for apps that use speech.")
                    }
                    .font(.callout)
                    .padding(.leading, 8)

                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "info.circle")
                        Text("Downloaded voices may take a few minutes to appear in this app. Restart the app if needed.")
                    }
                    .font(.footnote)
                    .italic()
                    .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    VoiceDownloadInfoView()
}
