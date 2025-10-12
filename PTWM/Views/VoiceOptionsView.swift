import SwiftUI
import AVFoundation

fileprivate let navigationVoices: [AVSpeechSynthesisVoice] = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
fileprivate let navigationVoiceIdentifiers: [String] = navigationVoices.map { $0.identifier }

struct VoiceOptionsView: View {
    @AppStorage("navigationVoiceIdentifier") private var navigationVoiceIdentifier: String = ""
    @AppStorage("navigationVoiceSpeed") private var navigationVoiceSpeed: Double = 0.48
    @AppStorage("navigationVoicePitch") private var navigationVoicePitch: Double = 1.0
    @Environment(\.dismiss) private var dismiss
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var searchText = ""
    @State private var showingSpeedPitchSettings = false
    
    private var filteredVoiceIdentifiers: [String] {
        if searchText.isEmpty {
            return [""] + navigationVoiceIdentifiers
        }
        return navigationVoiceIdentifiers.filter { identifier in
            if let voice = navigationVoices.first(where: { $0.identifier == identifier }) {
                return voice.name.localizedCaseInsensitiveContains(searchText)
            }
            return false
        }
    }
    
    private var groupedVoices: [(String, [String])] {
        var groups: [String: [String]] = [:]
        
        for identifier in filteredVoiceIdentifiers {
            if identifier.isEmpty {
                continue
            }
            guard let voice = navigationVoices.first(where: { $0.identifier == identifier }) else { continue }
            
            let locale = Locale(identifier: voice.language)
            let region = locale.localizedString(forRegionCode: locale.regionCode ?? "") ?? "Other"
            
            if groups[region] == nil {
                groups[region] = []
            }
            groups[region]?.append(identifier)
        }
        
        return groups.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationView {
            List {
                if searchText.isEmpty {
                    Section(header: Text("Default")) {
                        voiceRow(identifier: "")
                    }
                }
                
                ForEach(groupedVoices, id: \.0) { region, identifiers in
                    Section(header: Text(region)) {
                        ForEach(identifiers, id: \.self) { identifier in
                            voiceRow(identifier: identifier)
                        }
                    }
                }
                
                Section(header: Text("Voice Settings")) {
                    HStack {
                        Text("Speed")
                        Slider(value: $navigationVoiceSpeed, in: 0.3...0.7, step: 0.01)
                        Text(String(format: "%.2f", navigationVoiceSpeed))
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Pitch")
                        Slider(value: $navigationVoicePitch, in: 0.8...1.2, step: 0.01)
                        Text(String(format: "%.2f", navigationVoicePitch))
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .frame(width: 40)
                    }
                    
                    Button("Test Current Settings") {
                        playDemoWithCurrentSettings()
                    }
                    .buttonStyle(.bordered)
                }
                
                Section {
                    Button("Reset All to Default") {
                        navigationVoiceIdentifier = ""
                        navigationVoiceSpeed = 0.48
                        navigationVoicePitch = 1.0
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search voices")
            .navigationTitle("Navigation Voices")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    @ViewBuilder
    private func voiceRow(identifier: String) -> some View {
        HStack {
            Image(systemName: navigationVoiceIdentifier == identifier ? "checkmark.circle.fill" : "circle")
                .foregroundColor(.accentColor)
                .imageScale(.large)
            
            VStack(alignment: .leading, spacing: 2) {
                if identifier.isEmpty {
                    Text("Default (Auto)")
                        .font(.body)
                } else if let voice = navigationVoices.first(where: { $0.identifier == identifier }) {
                    Text(voice.name)
                        .font(.body)
                    HStack(spacing: 4) {
                        if voice.quality == .enhanced {
                            Text("Enhanced")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                        if voice.identifier.contains("siri") {
                            Text("Siri")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                        Text(voice.language)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Unknown Voice")
                }
            }
            
            Spacer()
            
            if !identifier.isEmpty, let voice = navigationVoices.first(where: { $0.identifier == identifier }) {
                Button(action: {
                    playDemo(for: voice)
                }) {
                    Image(systemName: "play.circle.fill")
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Demo \(voice.name)")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            navigationVoiceIdentifier = identifier
            if !identifier.isEmpty {
                if let voice = navigationVoices.first(where: { $0.identifier == identifier }) {
                    playDemo(for: voice)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func playDemo(for voice: AVSpeechSynthesisVoice) {
        let utterance = AVSpeechUtterance(string: "This is how your navigation instructions will sound.")
        utterance.voice = voice
        utterance.rate = Float(navigationVoiceSpeed)
        utterance.pitchMultiplier = Float(navigationVoicePitch)
        utterance.volume = 1.0
        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.speak(utterance)
    }
    
    private func playDemoWithCurrentSettings() {
        let voice: AVSpeechSynthesisVoice? = navigationVoiceIdentifier.isEmpty ? nil : navigationVoices.first(where: { $0.identifier == navigationVoiceIdentifier })
        let utterance = AVSpeechUtterance(string: "Turn left in 500 feet. Then continue straight for 2 miles.")
        utterance.voice = voice
        utterance.rate = Float(navigationVoiceSpeed)
        utterance.pitchMultiplier = Float(navigationVoicePitch)
        utterance.volume = 1.0
        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.speak(utterance)
    }
}

#Preview {
    VoiceOptionsView()
}
