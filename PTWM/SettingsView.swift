//  SettingsView.swift
//  waylonApp
//
//  Created by Assistant on 6/30/25.
//

import SwiftUI
import CoreLocation
import AVFoundation
import CoreMotion
import UIKit
import MapKit

fileprivate let navigationVoices: [AVSpeechSynthesisVoice] = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
fileprivate let navigationVoiceIdentifiers: [String] = navigationVoices.map { $0.identifier }

class LocationPermissionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var status: CLAuthorizationStatus = CLLocationManager.authorizationStatus()
    private let manager = CLLocationManager()
    override init() {
        super.init()
        manager.delegate = self
    }
    func request() { manager.requestWhenInUseAuthorization() }
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.status = status
    }
}

class MotionPermissionManager: ObservableObject {
    @Published var status: CMAuthorizationStatus = CMMotionActivityManager.authorizationStatus()
    func request() {
        let activityManager = CMMotionActivityManager()
        activityManager.queryActivityStarting(from: Date(), to: Date(), to: .main) { _, _ in
            DispatchQueue.main.async {
                self.status = CMMotionActivityManager.authorizationStatus()
            }
        }
    }
}

class MicrophonePermissionManager: ObservableObject {
    @Published var status: AVAudioSession.RecordPermission = AVAudioSession.sharedInstance().recordPermission
    func request() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.status = AVAudioSession.sharedInstance().recordPermission
            }
        }
    }
}

struct SettingsView: View {
    @AppStorage("userFirstName") private var userFirstName: String = ""
    @AppStorage("appDarkMode") private var appDarkMode: Bool = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @AppStorage("useKilometers") private var useKilometers: Bool = false
    // 0: Standard, 1: Satellite, 2: Hybrid, 3: Muted Standard
    @AppStorage("selectedMapStyle") private var selectedMapStyle: Int = 0
    @AppStorage("navigationVoiceIdentifier") private var navigationVoiceIdentifier: String = ""

    @StateObject private var locationPermission = LocationPermissionManager()
    @StateObject private var motionPermission = MotionPermissionManager()
    @StateObject private var microphonePermission = MicrophonePermissionManager()
    @StateObject private var searchCompleter = AddressSearchCompleter()

    @EnvironmentObject var tripManager: TripManager
    
    @State private var showAbout = false
    @State private var showContact = false
    @State private var showingResetAlert = false
    @State private var showBackgroundSheet = false
    
    @State private var newFavoriteName = ""
    @State private var newFavoriteAddress = ""
    @State private var addressSuggestions: [MKLocalSearchCompletion] = []
    @State private var debounceWorkItem: DispatchWorkItem? = nil
    @State private var showSuggestions: Bool = false
    @State private var selectedSuggestion: MKLocalSearchCompletion? = nil

    var body: some View {
        BackgroundWrapper {
            NavigationView {
                Form {
                    Section(header: Text("Profile")) {
                        TextField("First Name", text: $userFirstName)
                        // Saved addresses for quick navigation
                        Button("Reset Onboarding (used for testing **IGNORE**)") {
                            hasSeenOnboarding = false
                        }
                    }
                    Section(header: Text("Favorite Addresses")) {
                        ForEach(tripManager.favoriteAddresses) { fav in
                            VStack(alignment: .leading) {
                                Text(fav.name).bold()
                                Text(fav.address).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .onDelete { offsets in
                            tripManager.removeFavoriteAddress(at: offsets)
                        }
                        HStack(spacing: 8) {
                            TextField("Name (e.g. Mom's House)", text: $newFavoriteName)
                            TextField("Address", text: $newFavoriteAddress)
                                .onChange(of: newFavoriteAddress) { newValue in
                                    debounceWorkItem?.cancel()
                                    if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                                        showSuggestions = false
                                        addressSuggestions = []
                                    } else {
                                        showSuggestions = true
                                        let workItem = DispatchWorkItem {
                                            searchCompleter.updateQuery(newValue)
                                        }
                                        debounceWorkItem = workItem
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
                                    }
                                }
                            Button(action: {
                                addFavoriteAddress()
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                            .disabled(newFavoriteName.trimmingCharacters(in: .whitespaces).isEmpty || newFavoriteAddress.trimmingCharacters(in: .whitespaces).isEmpty)
                            .accessibilityLabel("Add Favorite Address")
                        }
                        if showSuggestions && !addressSuggestions.isEmpty {
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(addressSuggestions, id: \.self) { suggestion in
                                        Button(action: {
                                            newFavoriteAddress = suggestion.title + (suggestion.subtitle.isEmpty ? "" : ", \(suggestion.subtitle)")
                                            showSuggestions = false
                                        }) {
                                            VStack(alignment: .leading) {
                                                Text(suggestion.title).fontWeight(.medium)
                                                if !suggestion.subtitle.isEmpty {
                                                    Text(suggestion.subtitle).font(.caption).foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        Divider()
                                    }
                                }
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(8)
                                .shadow(radius: 2)
                            }
                            .frame(maxHeight: 150)
                        }
                    }
                    Section(header: Text("Background")) {
                        Button("Customize Background") {
                            showBackgroundSheet.toggle()
                        }
                    }
                    Section(header: Text("Appearance")) {
                        Toggle(isOn: $appDarkMode) {
                            Text("Dark Mode")
                        }
                        Toggle(isOn: $useKilometers) {
                            Text("Use Kilometers")
                        }
                        // User-selectable map style
                        Picker("Map Style", selection: $selectedMapStyle) {
                            Text("Standard").tag(0)
                            Text("Satellite").tag(1)
                            Text("Hybrid").tag(2)
                            Text("Muted Standard").tag(3)
                        }
                        .pickerStyle(.menu)
                    }
                    Section(header: Text("Navigation Voice")) {
                        // User-selectable voice for turn-by-turn navigation
                        Picker("Voice", selection: $navigationVoiceIdentifier) {
                            ForEach([""] + navigationVoiceIdentifiers, id: \.self) { identifier in
                                if identifier.isEmpty {
                                    Text("Default (Auto)").tag("")
                                } else if let voice = navigationVoices.first(where: { $0.identifier == identifier }) {
                                    Text(voice.name + (voice.quality == .enhanced ? " (Enhanced)" : "") + (voice.identifier.contains("siri") ? " (Siri)" : "")).tag(identifier)
                                } else {
                                    Text("Unknown Voice").tag(identifier)
                                }
                            }
                        }
                        Button("Reset to Default") {
                            navigationVoiceIdentifier = ""
                        }
                    }
                    Section(header: Text("Privacy & Permissions")) {
                        HStack {
                            Text("Location")
                            Spacer()
                            Text(locationStatusText)
                                .foregroundColor(locationAuthorized ? .green : .red)
                            if !locationAuthorized {
                                Button("Request") { locationPermission.request() }
                                    .buttonStyle(BorderlessButtonStyle())
                            }
                        }
                        HStack {
                            Text("Motion")
                            Spacer()
                            Text(motionStatusText)
                                .foregroundColor(motionAuthorized ? .green : .red)
                            if !motionAuthorized {
                                Button("Request") { motionPermission.request() }
                                    .buttonStyle(BorderlessButtonStyle())
                            }
                        }
                        HStack {
                            Text("Microphone")
                            Spacer()
                            Text(microphoneStatusText)
                                .foregroundColor(microphoneAuthorized ? .green : .red)
                            if !microphoneAuthorized {
                                Button("Request") { microphonePermission.request() }
                                    .buttonStyle(BorderlessButtonStyle())
                            }
                        }
                    }
                    Section {
                        Button("Contact Information") {
                            showContact = true
                        }
                    }
                    Section {
                        Button("About") {
                            showAbout = true
                        }
                    }
                    Section {
                        Button("Reset App to Stock Settings") {
                            showingResetAlert = true
                        }
                        .foregroundColor(.red)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .navigationTitle("Settings")
                .onReceive(searchCompleter.$suggestions) { suggestions in
                    addressSuggestions = suggestions
                }
            }
            .sheet(isPresented: $showAbout) {
                InfoView()
            }
            .sheet(isPresented: $showContact) {
                ContactInfoView()
            }
            .sheet(isPresented: $showBackgroundSheet) {
                BackgroundView()
            }
            .alert("Reset App to Stock Settings", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    resetAppToStockSettings()
                }
            } message: {
                Text("Are you sure you want to reset the app? This will clear all your settings and saved data.")
            }
        }
    }
    
    private func addFavoriteAddress() {
        let trimmedName = newFavoriteName.trimmingCharacters(in: .whitespaces)
        let trimmedAddress = newFavoriteAddress.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !trimmedAddress.isEmpty else { return }
        let favorite = FavoriteAddress(name: trimmedName, address: trimmedAddress)
        tripManager.addFavoriteAddress(favorite)
        newFavoriteName = ""
        newFavoriteAddress = ""
    }
    
    private func resetAppToStockSettings() {
        // Remove UserDefaults keys except for appDarkMode
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "userFirstName")
        defaults.removeObject(forKey: "userHomeAddress")
        defaults.removeObject(forKey: "userWorkAddress")
        defaults.removeObject(forKey: "hasSeenOnboarding")
        defaults.removeObject(forKey: "savedTrips")
        defaults.removeObject(forKey: "savedBackground")
        
        // Clear TripManager data
        tripManager.trips.removeAll()
        tripManager.removeBackgroundImage()
        
        // Reset @AppStorage values except appDarkMode
        userFirstName = ""
        hasSeenOnboarding = false
    }
    
    private var locationAuthorized: Bool {
        switch locationPermission.status {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }
    
    private var locationStatusText: String {
        switch locationPermission.status {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Authorized Always"
        case .authorizedWhenInUse: return "Authorized When In Use"
        @unknown default: return "Unknown"
        }
    }
    
    private var motionAuthorized: Bool {
        switch motionPermission.status {
        case .authorized:
            return true
        case .notDetermined, .restricted, .denied:
            return false
        @unknown default:
            return false
        }
    }
    
    private var motionStatusText: String {
        switch motionPermission.status {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        @unknown default: return "Unknown"
        }
    }
    
    private var microphoneAuthorized: Bool {
        microphonePermission.status == .granted
    }
    
    private var microphoneStatusText: String {
        switch microphonePermission.status {
        case .undetermined: return "Not Determined"
        case .denied: return "Denied"
        case .granted: return "Authorized"
        @unknown default: return "Unknown"
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(TripManager())
}
