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
import UserNotifications
import StoreKit
import LocalAuthentication

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
    @AppStorage("muteSpokenNavigation") private var muteSpokenNavigation: Bool = false
    @AppStorage("showTrafficOnMap") private var showTrafficOnMap: Bool = true
    @AppStorage("enableSpeedTracking") private var enableSpeedTracking: Bool = false

    @AppStorage("defaultTripCategory") private var defaultTripCategory: String = "Business"
    @AppStorage("tripCategories") private var tripCategoriesData: String = ""
    @AppStorage("autoTripDetectionEnabled") private var autoTripDetectionEnabled: Bool = false
    @AppStorage("autoTripSpeedThresholdMPH") private var autoTripSpeedThresholdMPH: Double = 20.0
    @AppStorage("autoTripEndDelaySecs") private var autoTripEndDelaySecs: Double = 180.0
    
    @AppStorage("tripLogProtectionEnabled") private var tripLogProtectionEnabled: Bool = false
    @AppStorage("tripLogProtectionMethod") private var tripLogProtectionMethod: String = "biometric" // or "passcode"
    
    @AppStorage("cityMPG") private var cityMPG: Double = 25.0
    @AppStorage("highwayMPG") private var highwayMPG: Double = 32.0
    @AppStorage("gasPricePerGallon") private var gasPricePerGallon: Double = 3.99

    // Only "Other" category is always retained
    private let fixedCategories = [
        "Other"
    ]
    
    // Default categories that cannot be renamed but can be deleted (except "Other")
    private let defaultCategories = [
        "Business", "Personal", "Vacation", "Photography", "DoorDash", "Uber"
    ]

    // Compute categories from saved data, ensuring "Other" is always present at the end
    private var categories: [String] {
        let decoded = (try? JSONDecoder().decode([String].self, from: Data(tripCategoriesData.utf8))) ?? []
        var unique = Array(Set(decoded))
        // Ensure "Other" is present
        if !unique.contains("Other") {
            unique.append("Other")
        }
        // Sort so that "Other" is always at the end, others alphabetically
        unique = unique.filter { $0 != "Other" }.sorted() + ["Other"]
        return unique
    }

    // Save categories, ensuring "Other" is present at the end
    private func saveCategories(_ newCategories: [String]) {
        var all = Array(Set(newCategories))
        if !all.contains("Other") {
            all.append("Other")
        }
        // Sort so that "Other" is always at the end, others alphabetically
        all = all.filter { $0 != "Other" }.sorted() + ["Other"]
        if let data = try? JSONEncoder().encode(all) {
            tripCategoriesData = String(data: data, encoding: .utf8) ?? tripCategoriesData
        }
    }

    @State private var newCategory = ""
    @State private var editingCategory: String? = nil
    @State private var renameValue: String = ""
    @State private var showJamesDrozImage = false
    @State private var showWhatsNew = false

    @StateObject private var locationPermission = LocationPermissionManager()
    @StateObject private var motionPermission = MotionPermissionManager()
    @StateObject private var microphonePermission = MicrophonePermissionManager()
    @StateObject private var searchCompleter = AddressSearchCompleter()
    @StateObject private var premiumManager = PremiumManager.shared

    @EnvironmentObject var tripManager: TripManager
    
    @State private var showAbout = false
    @State private var showContact = false
    @State private var searchText = ""
    @State private var showingSearchResults = false
    
    // Computed property for searchable settings
    private var filteredSections: [(String, [String])] {
        let allSettings = [
            ("Profile", ["First Name", "Favorite Addresses"]),
            ("Trip Settings", ["Default Category", "Trip Categories", "Trip Detection", "Trip Log Protection"]),
            ("Appearance", ["Dark Mode", "Units", "Map Style", "Traffic", "Speed Tracking"]),
            ("Navigation", ["Voice Settings", "Spoken Navigation"]),
            ("Fuel Economy", ["City MPG", "Highway MPG", "Gas Price"]),
            ("Privacy", ["Location", "Motion", "Microphone", "Notifications"])
        ]
        
        if searchText.isEmpty {
            return allSettings
        }
        
        return allSettings.compactMap { section, items in
            let filteredItems = items.filter { $0.localizedCaseInsensitiveContains(searchText) }
            return filteredItems.isEmpty ? nil : (section, filteredItems)
        }
    }
    
    @State private var newFavoriteName = ""
    @State private var newFavoriteAddress = ""
    @State private var addressSuggestions: [MKLocalSearchCompletion] = []
    @State private var debounceWorkItem: DispatchWorkItem? = nil
    @State private var showSuggestions: Bool = false
    @State private var selectedSuggestion: MKLocalSearchCompletion? = nil
    
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var showVoiceOptions = false
    @State private var showVoiceDownloadInfo = false
    
    @State private var showCategoryManager = false
    
    @State private var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined

    @State private var showBypassSheet = false
    @State private var bypassCodeInput = ""
    @State private var bypassErrorMessage: String? = nil

    @State private var showLogLockAuthError = false
    @State private var logLockAuthErrorMessage = ""
    
    @State private var showingResetAlert = false
    @State private var showBackgroundSheet = false

    private var appVersion: String {
        let dict = Bundle.main.infoDictionary
        let version = dict?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = dict?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func updateNotificationPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationPermissionStatus = settings.authorizationStatus
            }
        }
    }

    var body: some View {
        BackgroundWrapper {
            NavigationView {
                Form {
                    Section {
                        if premiumManager.isPremium {
                            HStack {
                                Image(systemName: "star.fill").foregroundColor(.yellow)
                                Text("Premium Unlocked!").bold().foregroundColor(.accentColor)
                                Spacer()
                            }
                            .padding()
                            .modifier(GlassEffectModifier(cornerRadius: 12, tintColor: .yellow.opacity(0.2)))
                        } else {
                            VStack(spacing: 12) {
                                Button(action: {
                                    Task { await premiumManager.purchasePremium() }
                                }) {
                                    HStack {
                                        Image(systemName: "star.circle.fill").foregroundColor(.yellow)
                                        Text("Buy Premium")
                                        if premiumManager.purchaseInProgress {
                                            ProgressView().scaleEffect(0.8)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                }
                                .buttonStyle(GlassProminentButtonStyle())
                                .disabled(premiumManager.purchaseInProgress)
                                
                                Button(action: {
                                    Task { await premiumManager.restorePurchases() }
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.counterclockwise.circle.fill").foregroundColor(.blue)
                                        Text("Restore Purchase")
                                        if premiumManager.purchaseInProgress {
                                            ProgressView().scaleEffect(0.8)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                }
                                .buttonStyle(GlassButtonStyle())
                                .disabled(premiumManager.purchaseInProgress)
                                .accessibilityIdentifier("RestorePurchaseButton")
                            }
                            .alert(isPresented: .constant(premiumManager.purchaseError != nil)) {
                                Alert(title: Text("Purchase Error"), message: Text(premiumManager.purchaseError ?? ""), dismissButton: .default(Text("OK"), action: { premiumManager.purchaseError = nil }))
                            }
                        }
                    }
                    
                    Section(header: Text("Quick Actions")) {
                        VStack(spacing: 16) {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                                QuickActionButton(
                                    icon: "location",
                                    title: "Export GPX",
                                    action: { exportTripData() }
                                )
                                
                                QuickActionButton(
                                    icon: "square.and.arrow.up",
                                    title: "Share App",
                                    action: { shareApp() }
                                )
                                
                                QuickActionButton(
                                    icon: "trash",
                                    title: "Clear Cache",
                                    action: { clearCache() }
                                )
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    Section(header: Text("Profile")) {
                        TextField("First Name", text: $userFirstName)
                        // Saved addresses for quick navigation
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
                    
                    Section(header: Text("Default Trip Category")) {
                        Picker("Default Category", selection: $defaultTripCategory) {
                            ForEach(categories, id: \.self) { category in
                                Text(category).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        // Removed .disabled(!premiumManager.isPremium)
                        if !premiumManager.isPremium {
                            Text("Selecting a default category is a Premium feature.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        Text("This category will be used automatically for new trip logs.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Section {
                        Button("Manage Trip Categories") {
                            showCategoryManager = true
                        }
                        // Removed .disabled(!premiumManager.isPremium)
                        if !premiumManager.isPremium {
                            Text("Managing trip categories is a Premium feature.")
                                .font(.caption)
                                .foregroundColor(.orange)
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
                        Toggle(isOn: $showTrafficOnMap) {
                            Text("Show Traffic on Map")
                        }
                        .accessibilityIdentifier("ShowTrafficOnMapToggle")
                        Toggle(isOn: $enableSpeedTracking) {
                            Text("Enable Speed Tracking")
                        }
                        .accessibilityIdentifier("EnableSpeedTrackingToggle")
                        // Removed .disabled(!premiumManager.isPremium)
                        if !premiumManager.isPremium {
                            Text("Enabling speed tracking is a Premium feature.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        Text("When enabled, your current speed and average speed will be displayed and logged in trip reports.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Section(header: Text("Fuel Economy Settings")) {
                        HStack {
                            Text("City MPG")
                            Spacer()
                            TextField("--", value: $cityMPG, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        HStack {
                            Text("Highway MPG")
                            Spacer()
                            TextField("--", value: $highwayMPG, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        HStack {
                            Text("Gas Price (per gallon)")
                            Spacer()
                            TextField("--", value: $gasPricePerGallon, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        Text("This price is used to estimate trip fuel cost in your trip logs.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Section(header: Text("Navigation Voice")) {
                        Button {
                            showVoiceOptions = true
                        } label: {
                            HStack {
                                Text("Navigation Voices")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        Button {
                            showVoiceDownloadInfo = true
                        } label: {
                            HStack {
                                Text("How to download new voices?")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Section(header: Text("Spoken Navigation")) {
                        Toggle(isOn: $muteSpokenNavigation) {
                            Text("Mute Spoken Navigation")
                        }
                        .accessibilityIdentifier("MuteSpokenNavigationToggle")
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
                        HStack {
                            Text("Notifications")
                            Spacer()
                            Text(notificationPermissionStatus == .authorized ? "Authorized" : (notificationPermissionStatus == .denied ? "Denied" : "Not Determined"))
                                .foregroundColor(notificationPermissionStatus == .authorized ? .green : .red)
                        }
                    }
                    Section(header: Text("Trip Detection")) {
                        Toggle(isOn: $autoTripDetectionEnabled) {
                            Text("Automatic Trip Detection")
                        }
                        // Removed .disabled(!premiumManager.isPremium)
                        if !premiumManager.isPremium {
                            Text("Automatic Trip Detection is a Premium feature.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        Text("When enabled, trips will automatically start and end based on your speed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Auto-Start Speed Threshold")
                                Spacer()
                                Text(String(format: "%.0f mph", autoTripSpeedThresholdMPH))
                            }
                            Slider(value: $autoTripSpeedThresholdMPH, in: 5...50, step: 1)
                            Text("Trips will automatically start when you exceed this speed.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack {
                                Text("End Trip Automatically After This Long")
                                Spacer()
                                Text("\(Int(autoTripEndDelaySecs/60)) min \(Int(autoTripEndDelaySecs) % 60) sec")
                            }
                            Slider(value: $autoTripEndDelaySecs, in: 30...600, step: 1)
                            Text("Trip will end if you remain below the speed threshold for this amount of time.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Section(header: Text("Trip Log Protection")) {
                        Toggle(isOn: Binding<Bool>(
                            get: { tripLogProtectionEnabled },
                            set: { newValue in
                                if !newValue {
                                    authenticateBeforeDisablingLogLock()
                                } else {
                                    tripLogProtectionEnabled = true
                                }
                            }
                        )) {
                            Text("Require authentication to view trip logs")
                        }
                        .alert("Authentication Failed", isPresented: $showLogLockAuthError) {
                            Button("OK", role: .cancel) { }
                        } message: {
                            Text(logLockAuthErrorMessage)
                        }
                        if tripLogProtectionEnabled {
                            Picker("Authentication Method", selection: $tripLogProtectionMethod) {
                                Text("Face ID / Touch ID").tag("biometric")
                                Text("Passcode or Biometrics").tag("passcode")
                            }
                            .pickerStyle(.segmented)
                            Text("If enabled, you'll need to authenticate using your chosen method before accessing your trip logs.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                    }
                    
                    Section {
                        Button("Contact Information") {
                            showContact = true
                        }
                    }
                    Section {
                        Button("What’s New") {
                            showWhatsNew = true
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
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Menu {
                            Button(action: { showAbout = true }) {
                                Label("About", systemImage: "info.circle")
                            }
                            Button(action: { showContact = true }) {
                                Label("Contact", systemImage: "envelope")
                            }
                            Button(action: { showWhatsNew = true }) {
                                Label("What's New", systemImage: "sparkles")
                            }
                            Divider()
                            Button(action: { showBypassSheet = true }) {
                                Label("Developer", systemImage: "key.fill")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .onReceive(searchCompleter.$suggestions) { suggestions in
                    addressSuggestions = suggestions
                }
                .onAppear { updateNotificationPermissionStatus() }
                .sheet(isPresented: $showVoiceOptions) {
                    VoiceOptionsView()
                }
                .sheet(isPresented: $showVoiceDownloadInfo) {
                    VoiceDownloadInfoView()
                }
                .sheet(isPresented: $showCategoryManager) {
                    CategoryManagerView()
                }
                .sheet(isPresented: $showBypassSheet) {
                    VStack(spacing: 16) {
                        Text("Enter Bypass Code")
                            .font(.headline)
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("The code is case sensitive")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        TextField("Bypass Code (e.g. This app is the best!!)", text: $bypassCodeInput)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding()
                        if let error = bypassErrorMessage {
                            Text(error)
                                .foregroundColor(.red)
                        }
                        HStack(spacing: 20) {
                            Button("Unlock Premium") {
                                if bypassCodeInput == "unlockpremium"{
                                    PremiumManager.shared.isPremium = true
                                    UserDefaults.standard.set(true, forKey: "hasPremium")
                                    showBypassSheet = false
                                    bypassCodeInput = ""
                                    bypassErrorMessage = nil
                                } else if bypassCodeInput == "lockpremium" {
                                    PremiumManager.shared.isPremium = false
                                    UserDefaults.standard.set(false, forKey: "hasPremium")
                                    showBypassSheet = false
                                    bypassCodeInput = ""
                                    bypassErrorMessage = nil
                                } else if bypassCodeInput == "jamesdroz" {
                                    showBypassSheet = false
                                    bypassCodeInput = ""
                                    bypassErrorMessage = nil
                                    showJamesDrozImage = true
                                } else {
                                    bypassErrorMessage = "Incorrect code."
                                }
                            }
                            Button("Cancel") {
                                showBypassSheet = false
                                bypassCodeInput = ""
                                bypassErrorMessage = nil
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: 400)
                }
                .sheet(isPresented: $showJamesDrozImage) {
                    JamesDrozImageView()
                }
                .sheet(isPresented: $showWhatsNew) {
                    WhatsNewView(currentVersion: appVersion, onDismiss: { showWhatsNew = false })
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
        defaults.removeObject(forKey: "defaultTripCategory")
        defaults.removeObject(forKey: "tripCategories")
        defaults.removeObject(forKey: "autoTripDetectionEnabled")
        
        // Clear TripManager data
        tripManager.trips.removeAll()
        tripManager.removeBackgroundImage()

        // Reset @AppStorage values except appDarkMode
        userFirstName = ""
        hasSeenOnboarding = false
        defaultTripCategory = "Business"
        autoTripDetectionEnabled = false
        saveCategories(["Other"])
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
    
    private func authenticateBeforeDisablingLogLock() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock to change log protection settings") { success, evalError in
                DispatchQueue.main.async {
                    if success {
                        tripLogProtectionEnabled = false
                        showLogLockAuthError = false
                        logLockAuthErrorMessage = ""
                    } else {
                        showLogLockAuthError = true
                        logLockAuthErrorMessage = evalError?.localizedDescription ?? "Authentication failed."
                    }
                }
            }
        } else {
            showLogLockAuthError = true
            logLockAuthErrorMessage = error?.localizedDescription ?? "Face ID or Touch ID not available."
        }
    }
    
    // MARK: - Quick Action Functions
    private func exportTripData() {
        // Implementation for exporting trip data as GPX
        print("Export trip data requested")
    }
    
    private func shareApp() {
        // Implementation for sharing the app
        let activityVC = UIActivityViewController(
            activityItems: ["Check out this amazing trip tracking app: WaylonApp"],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func clearCache() {
        // Implementation for clearing app cache
        URLCache.shared.removeAllCachedResponses()
        print("Cache cleared")
    }
}

// MARK: - Supporting Views

struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.primary)
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(12)
        }
        .buttonStyle(GlassButtonStyle())
    }
}

// MARK: - Custom Button Styles

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct GlassProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.thickMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.blue.opacity(0.3))
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Glass Effect Modifier for Compatibility

struct GlassEffectModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tintColor: Color?
    
    init(cornerRadius: CGFloat = 12, tintColor: Color? = nil) {
        self.cornerRadius = cornerRadius
        self.tintColor = tintColor
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(tintColor ?? Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            )
    }
}

#Preview {
    SettingsView()
        .environmentObject(TripManager())
        .environmentObject(PremiumManager.shared)
}

