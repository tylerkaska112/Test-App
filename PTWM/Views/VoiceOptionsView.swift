import SwiftUI
import AVFoundation

fileprivate let navigationVoices: [AVSpeechSynthesisVoice] = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
fileprivate let navigationVoiceIdentifiers: [String] = navigationVoices.map { $0.identifier }

struct VoiceOptionsView: View {
    @AppStorage("navigationVoiceIdentifier") private var navigationVoiceIdentifier: String = ""
    @Environment(\.dismiss) private var dismiss
    @State private var speechSynthesizer = AVSpeechSynthesizer()

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Select Navigation Voice")) {
                    ForEach([""] + navigationVoiceIdentifiers, id: \.self) { identifier in
                        HStack {
                            Image(systemName: navigationVoiceIdentifier == identifier ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(.accentColor)
                                .onTapGesture { navigationVoiceIdentifier = identifier }

                            if identifier.isEmpty {
                                Text("Default (Auto)")
                            } else if let voice = navigationVoices.first(where: { $0.identifier == identifier }) {
                                Text(voice.name + (voice.quality == .enhanced ? " (Enhanced)" : "") + (voice.identifier.contains("siri") ? " (Siri)" : ""))
                            } else {
                                Text("Unknown Voice")
                            }
                            Spacer()
                            if let voice = navigationVoices.first(where: { $0.identifier == identifier }), !identifier.isEmpty {
                                Button("Demo") {
                                    let utterance = AVSpeechUtterance(string: "This is how your navigation instructions will sound.")
                                    utterance.voice = voice
                                    utterance.rate = 0.48
                                    utterance.pitchMultiplier = 1.0
                                    utterance.volume = 1.0
                                    speechSynthesizer.stopSpeaking(at: .immediate)
                                    speechSynthesizer.speak(utterance)
                                }
                                .buttonStyle(.bordered)
                                .accessibilityLabel("Demo \(voice.name)")
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { navigationVoiceIdentifier = identifier }
                        .padding(.vertical, 4)
                    }
                }
                Section {
                    Button("Reset to Default") {
                        navigationVoiceIdentifier = ""
                    }
                }
            }
            .navigationTitle("Navigation Voices")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    VoiceOptionsView()
}
