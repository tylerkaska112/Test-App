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

// MARK: - Vehicle Model
struct Vehicle: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var cityMPG: Double
    var highwayMPG: Double
    var fuelTankCapacity: Double
    
    init(id: String = UUID().uuidString, name: String, cityMPG: Double, highwayMPG: Double, fuelTankCapacity: Double = 15.0) {
        self.id = id
        self.name = name
        self.cityMPG = cityMPG
        self.highwayMPG = highwayMPG
        self.fuelTankCapacity = fuelTankCapacity
    }
}

struct SettingsView: View {
    @AppStorage("userFirstName") private var userFirstName: String = ""
    @AppStorage("appDarkMode") private var appDarkMode: Bool = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @AppStorage("useKilometers") private var useKilometers: Bool = false
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
    @AppStorage("tripLogProtectionMethod") private var tripLogProtectionMethod: String = "biometric"
    
    @AppStorage("cityMPG") private var cityMPG: Double = 25.0
    @AppStorage("highwayMPG") private var highwayMPG: Double = 32.0
    @AppStorage("gasPricePerGallon") private var gasPricePerGallon: Double = 3.99
    
    // NEW: Enhanced Settings
    @AppStorage("minimumTripDistance") private var minimumTripDistance: Double = 0.5
    @AppStorage("autoDeleteTripsAfterDays") private var autoDeleteTripsAfterDays: Int = 0
    @AppStorage("speedLimitWarningEnabled") private var speedLimitWarningEnabled: Bool = false
    @AppStorage("speedLimitThreshold") private var speedLimitThreshold: Double = 75.0
    @AppStorage("showPOIOnMap") private var showPOIOnMap: Bool = true
    @AppStorage("show3DBuildings") private var show3DBuildings: Bool = true
    @AppStorage("showMapCompass") private var showMapCompass: Bool = true
    @AppStorage("showMapScale") private var showMapScale: Bool = false
    @AppStorage("batterySavingMode") private var batterySavingMode: Bool = false
    @AppStorage("gpsAccuracyMeters") private var gpsAccuracyMeters: Double = 10.0
    @AppStorage("selectedVehicleID") private var selectedVehicleID: String = ""
    @AppStorage("savedVehiclesData") private var savedVehiclesData: String = ""
    @AppStorage("blurHomeLocation") private var blurHomeLocation: Bool = false
    @AppStorage("blurWorkLocation") private var blurWorkLocation: Bool = false
    @AppStorage("useIRSMileageRate") private var useIRSMileageRate: Bool = false
    @AppStorage("customReimbursementRate") private var customReimbursementRate: Double = 0.67
    @AppStorage("fontSizeMultiplier") private var fontSizeMultiplier: Double = 1.0
    @AppStorage("accentColorName") private var accentColorName: String = "blue"

    private let fixedCategories = ["Other"]
    private let defaultCategories = ["Business", "Personal", "Vacation", "Photography", "DoorDash", "Uber"]

    private var categories: [String] {
        let decoded = (try? JSONDecoder().decode([String].self, from: Data(tripCategoriesData.utf8))) ?? []
        var unique = Array(Set(decoded))
        if !unique.contains("Other") {
            unique.append("Other")
        }
        unique = unique.filter { $0 != "Other" }.sorted() + ["Other"]
        return unique
    }

    private func saveCategories(_ newCategories: [String]) {
        var all = Array(Set(newCategories))
        if !all.contains("Other") {
            all.append("Other")
        }
        all = all.filter { $0 != "Other" }.sorted() + ["Other"]
        if let data = try? JSONEncoder().encode(all) {
            tripCategoriesData = String(data: data, encoding: .utf8) ?? tripCategoriesData
        }
    }
    
    // Vehicle Management
    private var vehicles: [Vehicle] {
        let trimmed = savedVehiclesData.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let data = Data(trimmed.utf8)
        guard let decoded = try? JSONDecoder().decode([Vehicle].self, from: data) else {
            return []
        }
        return decoded
    }
    
    private func saveVehicles(_ vehicles: [Vehicle]) {
        if let data = try? JSONEncoder().encode(vehicles),
           let str = String(data: data, encoding: .utf8) {
            savedVehiclesData = str
        }
    }
    
    private var selectedVehicle: Vehicle? {
        vehicles.first { $0.id == selectedVehicleID }
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
    @State private var showVehicleManager = false
    @State private var showDataManagement = false
    @State private var showPrivacySettings = false
    
    @State private var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined

    @State private var showBypassSheet = false
    @State private var bypassCodeInput = ""
    @State private var bypassErrorMessage: String? = nil

    @State private var showLogLockAuthError = false
    @State private var logLockAuthErrorMessage = ""
    
    @State private var showingResetAlert = false
    @State private var showBackgroundSheet = false
    
    @State private var expandedSections: Set<String> = []

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
                ScrollView {
                    VStack(spacing: 16) {
                        // Premium Status Card
                        premiumStatusCard
                        
                        // Quick Actions
                        quickActionsCard
                        
                        // Profile Section
                        profileCard
                        
                        // Trip Management
                        tripManagementCard
                        
                        // Appearance & Display
                        appearanceCard
                        
                        // Map Settings
                        mapSettingsCard
                        
                        // Navigation & Voice
                        navigationCard
                        
                        // Vehicle & Fuel
                        vehicleCard
                        
                        // Privacy & Security
                        privacyCard
                        
                        // Performance
                        performanceCard
                        
                        // Data Management
                        dataManagementCard
                        
                        // About & Support
                        aboutCard
                        
                        // Danger Zone
                        dangerZoneCard
                    }
                    .padding()
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .navigationTitle("Settings")
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
                .onAppear {
                    updateNotificationPermissionStatus()
                    initializeDefaultVehicleIfNeeded()
                }
                .sheet(isPresented: $showVoiceOptions) {
                    VoiceOptionsView()
                }
                .sheet(isPresented: $showVoiceDownloadInfo) {
                    VoiceDownloadInfoView()
                }
                .sheet(isPresented: $showCategoryManager) {
                    CategoryManagerView()
                }
                .sheet(isPresented: $showVehicleManager) {
                    VehicleManagerView(vehicles: vehicles, selectedVehicleID: $selectedVehicleID, onSave: saveVehicles)
                }
                .sheet(isPresented: $showDataManagement) {
                    DataManagementView()
                }
                .sheet(isPresented: $showPrivacySettings) {
                    PrivacySettingsView()
                }
                .sheet(isPresented: $showBypassSheet) {
                    BypassCodeView(isPresented: $showBypassSheet, showJamesDrozImage: $showJamesDrozImage)
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
    
    // MARK: - Card Views
    
    private var premiumStatusCard: some View {
        SettingsCard(icon: "star.fill", title: "Premium", iconColor: .yellow) {
            if premiumManager.isPremium {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("Premium Unlocked!").bold()
                    Spacer()
                }
            } else {
                VStack(spacing: 12) {
                    Button(action: {
                        Task { await premiumManager.purchasePremium() }
                    }) {
                        HStack {
                            Image(systemName: "star.circle.fill").foregroundColor(.yellow)
                            Text("Unlock Premium")
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
    }
    
    private var quickActionsCard: some View {
        SettingsCard(icon: "bolt.fill", title: "Quick Actions", iconColor: .orange) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                QuickActionButton(icon: "square.and.arrow.up.on.square", title: "Export GPX", action: exportTripData)
                QuickActionButton(icon: "square.and.arrow.up", title: "Share App", action: shareApp)
                QuickActionButton(icon: "trash", title: "Clear Cache", action: clearCache)
            }
        }
    }
    
    private var profileCard: some View {
        SettingsCard(icon: "person.fill", title: "Profile", iconColor: .blue) {
            VStack(spacing: 16) {
                HStack {
                    Text("First Name")
                    Spacer()
                    TextField("Your name", text: $userFirstName)
                        .multilineTextAlignment(.trailing)
                }
                
                NavigationLink(destination: FavoriteAddressesView()) {
                    HStack {
                        Label("Favorite Addresses", systemImage: "mappin.and.ellipse")
                        Spacer()
                        Text("\(tripManager.favoriteAddresses.count)")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
    }
    
    private var tripManagementCard: some View {
        SettingsCard(icon: "car.fill", title: "Trip Management", iconColor: .green) {
            VStack(spacing: 16) {
                HStack {
                    Text("Default Category")
                    Spacer()
                    Picker("", selection: $defaultTripCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Button(action: { showCategoryManager = true }) {
                    HStack {
                        Label("Manage Categories", systemImage: "folder.badge.gearshape")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Divider()
                
                Toggle(isOn: $autoTripDetectionEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto Trip Detection")
                        Text("Start trips automatically")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if autoTripDetectionEnabled {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Start Speed")
                                Spacer()
                                Text("\(Int(autoTripSpeedThresholdMPH)) mph")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $autoTripSpeedThresholdMPH, in: 5...50, step: 1)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Min Trip Distance")
                                Spacer()
                                Text(String(format: "%.1f %@", minimumTripDistance, useKilometers ? "km" : "mi"))
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $minimumTripDistance, in: 0...5, step: 0.1)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("End Delay")
                                Spacer()
                                Text("\(Int(autoTripEndDelaySecs/60)) min")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $autoTripEndDelaySecs, in: 30...600, step: 30)
                        }
                    }
                }
            }
        }
    }
    
    private var appearanceCard: some View {
        SettingsCard(icon: "paintbrush.fill", title: "Appearance", iconColor: .purple) {
            VStack(spacing: 16) {
                Toggle(isOn: $appDarkMode) {
                    Label("Dark Mode", systemImage: "moon.fill")
                }
                
                Toggle(isOn: $useKilometers) {
                    Label("Use Kilometers", systemImage: "speedometer")
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Text Size")
                        Spacer()
                        Text("\(Int(fontSizeMultiplier * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $fontSizeMultiplier, in: 0.8...1.4, step: 0.1)
                }
            }
        }
    }
    
    private var mapSettingsCard: some View {
        SettingsCard(icon: "map.fill", title: "Map Settings", iconColor: .cyan) {
            VStack(spacing: 16) {
                HStack {
                    Text("Map Style")
                    Spacer()
                    Picker("", selection: $selectedMapStyle) {
                        Text("Standard").tag(0)
                        Text("Satellite").tag(1)
                        Text("Hybrid").tag(2)
                        Text("Muted").tag(3)
                    }
                    .pickerStyle(.menu)
                }
                
                Toggle(isOn: $showTrafficOnMap) {
                    Label("Show Traffic", systemImage: "car.2.fill")
                }
                
                Toggle(isOn: $showPOIOnMap) {
                    Label("Points of Interest", systemImage: "mappin.circle.fill")
                }
                
                Toggle(isOn: $show3DBuildings) {
                    Label("3D Buildings", systemImage: "building.2.fill")
                }
                
                Toggle(isOn: $showMapCompass) {
                    Label("Compass", systemImage: "location.north.fill")
                }
                
                Toggle(isOn: $showMapScale) {
                    Label("Scale Bar", systemImage: "ruler.fill")
                }
            }
        }
    }
    
    private var navigationCard: some View {
        SettingsCard(icon: "speaker.wave.3.fill", title: "Navigation & Voice", iconColor: .indigo) {
            VStack(spacing: 16) {
                Toggle(isOn: $muteSpokenNavigation) {
                    Label("Mute Navigation", systemImage: "speaker.slash.fill")
                }
                
                Button(action: { showVoiceOptions = true }) {
                    HStack {
                        Label("Voice Settings", systemImage: "waveform")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Toggle(isOn: $speedLimitWarningEnabled) {
                    Label("Speed Warnings", systemImage: "exclamationmark.triangle.fill")
                }
                
                if speedLimitWarningEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Warning Threshold")
                            Spacer()
                            Text("\(Int(speedLimitThreshold)) mph")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $speedLimitThreshold, in: 35...85, step: 5)
                    }
                }
            }
        }
    }
    
    private var vehicleCard: some View {
        SettingsCard(icon: "fuelpump.fill", title: "Vehicle & Fuel", iconColor: .orange) {
            VStack(spacing: 16) {
                if let vehicle = selectedVehicle {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vehicle.name).font(.headline)
                            HStack(spacing: 12) {
                                Label("\(Int(vehicle.cityMPG)) city", systemImage: "building.2.fill")
                                    .font(.caption)
                                Label("\(Int(vehicle.highwayMPG)) hwy", systemImage: "road.lanes")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    Text("No vehicle selected")
                        .foregroundColor(.secondary)
                }
                
                Button(action: { showVehicleManager = true }) {
                    HStack {
                        Label("Manage Vehicles", systemImage: "car.2.fill")
                        Spacer()
                        Text("\(vehicles.count)")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Divider()
                
                HStack {
                    Text("Gas Price")
                    Spacer()
                    Text("$")
                    TextField("3.99", value: $gasPricePerGallon, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text("/gal")
                        .foregroundColor(.secondary)
                }
                
                Toggle(isOn: $useIRSMileageRate) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Use IRS Mileage Rate")
                        Text("$\(customReimbursementRate, specifier: "%.2f")/mile")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var privacyCard: some View {
        SettingsCard(icon: "lock.shield.fill", title: "Privacy & Security", iconColor: .red) {
            VStack(spacing: 16) {
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trip Log Protection")
                        Text("Require authentication")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if tripLogProtectionEnabled {
                    Picker("Method", selection: $tripLogProtectionMethod) {
                        Text("Biometric").tag("biometric")
                        Text("Passcode").tag("passcode")
                    }
                    .pickerStyle(.segmented)
                }
                
                Divider()
                
                Toggle(isOn: $blurHomeLocation) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Blur Home Location")
                        Text("In exports and shares")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(isOn: $blurWorkLocation) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Blur Work Location")
                        Text("In exports and shares")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                Button(action: { showPrivacySettings = true }) {
                    HStack {
                        Label("Permissions", systemImage: "hand.raised.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
    }
    
    private var performanceCard: some View {
        SettingsCard(icon: "battery.100.bolt", title: "Performance", iconColor: .green) {
            VStack(spacing: 16) {
                Toggle(isOn: $batterySavingMode) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Battery Saving Mode")
                        Text("Reduced GPS accuracy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !batterySavingMode {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("GPS Accuracy")
                            Spacer()
                            Text("\(Int(gpsAccuracyMeters))m")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $gpsAccuracyMeters, in: 5...100, step: 5)
                        Text("Lower = more accurate, higher battery use")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(isOn: $enableSpeedTracking) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speed Tracking")
                        Text("Show speed data in trips")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var dataManagementCard: some View {
        SettingsCard(icon: "externaldrive.fill", title: "Data Management", iconColor: .blue) {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Trips")
                        Text("\(tripManager.trips.count)")
                            .font(.title2)
                            .bold()
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Distance")
                        Text(String(format: "%.1f %@", tripManager.trips.reduce(0) { $0 + $1.distance }, useKilometers ? "km" : "mi"))
                            .font(.title2)
                            .bold()
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                Button(action: exportAllTripsAsCSV) {
                    Label("Export as CSV", systemImage: "doc.text.fill")
                }
                
                Button(action: exportAllTripsAsJSON) {
                    Label("Backup Data (JSON)", systemImage: "square.and.arrow.down.fill")
                }
                
                Divider()
                
                HStack {
                    Text("Auto-Delete Trips")
                    Spacer()
                    Picker("", selection: $autoDeleteTripsAfterDays) {
                        Text("Never").tag(0)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                        Text("1 year").tag(365)
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
    
    private var aboutCard: some View {
        SettingsCard(icon: "info.circle.fill", title: "About & Support", iconColor: .gray) {
            VStack(spacing: 16) {
                Button(action: { showAbout = true }) {
                    HStack {
                        Label("About", systemImage: "info.circle")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Button(action: { showContact = true }) {
                    HStack {
                        Label("Contact", systemImage: "envelope")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Button(action: { showWhatsNew = true }) {
                    HStack {
                        Label("What's New", systemImage: "sparkles")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var dangerZoneCard: some View {
        SettingsCard(icon: "exclamationmark.triangle.fill", title: "Danger Zone", iconColor: .red) {
            Button(action: { showingResetAlert = true }) {
                HStack {
                    Label("Reset All Settings", systemImage: "arrow.counterclockwise.circle.fill")
                        .foregroundColor(.red)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func initializeDefaultVehicleIfNeeded() {
        if vehicles.isEmpty {
            let defaultVehicle = Vehicle(
                name: "My Car",
                cityMPG: cityMPG,
                highwayMPG: highwayMPG,
                fuelTankCapacity: 15.0
            )
            saveVehicles([defaultVehicle])
            selectedVehicleID = defaultVehicle.id
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
        
        tripManager.trips.removeAll()
        tripManager.removeBackgroundImage()

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
    
    private func exportTripData() {
        print("Export trip data requested")
    }
    
    private func shareApp() {
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
        URLCache.shared.removeAllCachedResponses()
        print("Cache cleared")
    }
    
    private func exportAllTripsAsCSV() {
        let csvString = generateTripCSV()
        shareContent(csvString, filename: "waylon_trips_\(Date().ISO8601Format()).csv")
    }
    
    private func exportAllTripsAsJSON() {
        guard let jsonData = try? JSONEncoder().encode(tripManager.trips),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        shareContent(jsonString, filename: "waylon_backup_\(Date().ISO8601Format()).json")
    }
    
    private func generateTripCSV() -> String {
        // Local formatters to avoid relying on unknown Trip string fields
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        func safeString(_ value: String?) -> String { value ?? "" }

        var csv = "Date,Start Time,End Time,Distance,Duration,Category,Start Address,End Address,Notes\n"
        for trip in tripManager.trips {
            // Try to infer commonly available properties. We assume Trip likely has start and end Date properties named
            // `start`/`end` or a single `date`. We compute strings defensively.
            var dateString = ""
            var startTimeString = ""
            var endTimeString = ""
            var durationString = ""

            // Reflect over potential common property names without using reflection APIs, just optional chaining patterns.
            // We'll use Swift optional casting via key paths not available here, so do a sequence of if-lets by accessing
            // known likely names using Mirror.
            let mirror = Mirror(reflecting: trip)
            var startDateValue: Date? = nil
            var endDateValue: Date? = nil
            var singleDateValue: Date? = nil

            for child in mirror.children {
                switch child.label {
                case "startDate", "start":
                    startDateValue = child.value as? Date
                case "endDate", "end":
                    endDateValue = child.value as? Date
                case "date":
                    singleDateValue = child.value as? Date
                default:
                    break
                }
            }

            if let start = startDateValue {
                dateString = dateFormatter.string(from: start)
                startTimeString = timeFormatter.string(from: start)
            } else if let date = singleDateValue {
                dateString = dateFormatter.string(from: date)
            }

            if let end = endDateValue {
                endTimeString = timeFormatter.string(from: end)
            }

            if let start = startDateValue, let end = endDateValue {
                let duration = end.timeIntervalSince(start)
                if duration > 0 {
                    let minutes = Int(duration / 60)
                    let hours = minutes / 60
                    let mins = minutes % 60
                    durationString = hours > 0 ? String(format: "%dh %dm", hours, mins) : String(format: "%dm", mins)
                }
            }

            let distance = String(format: "%.2f", trip.distance)
            let category = safeString((Mirror(reflecting: trip).children.first { $0.label == "category" }?.value as? String) ?? "")
            let startAddress = safeString((Mirror(reflecting: trip).children.first { $0.label == "startAddress" }?.value as? String) ?? "")
            let endAddress = safeString((Mirror(reflecting: trip).children.first { $0.label == "endAddress" }?.value as? String) ?? "")
            let notesRaw: String = {
                if let n = Mirror(reflecting: trip).children.first(where: { $0.label == "notes" })?.value as? String { return n }
                if let nOpt = Mirror(reflecting: trip).children.first(where: { $0.label == "notes" })?.value as? String? { return nOpt ?? "" }
                return ""
            }()
            let notes = notesRaw.replacingOccurrences(of: "\"", with: "\"\"")

            let row = "\"\(dateString)\",\"\(startTimeString)\",\"\(endTimeString)\",\(distance),\(durationString.isEmpty ? "" : durationString),\"\(category)\",\"\(startAddress)\",\"\(endAddress)\",\"\(notes)\"\n"
            csv += row
        }
        return csv
    }
    
    private func shareContent(_ content: String, filename: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? content.write(to: tempURL, atomically: true, encoding: .utf8)
        
        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - Supporting Views

struct SettingsCard<Content: View>: View {
    let icon: String
    let title: String
    let iconColor: Color
    let content: Content
    
    init(icon: String, title: String, iconColor: Color, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title2)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

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

// MARK: - Subviews

struct FavoriteAddressesView: View {
    @EnvironmentObject var tripManager: TripManager
    @StateObject private var searchCompleter = AddressSearchCompleter()
    
    @State private var newFavoriteName = ""
    @State private var newFavoriteAddress = ""
    @State private var addressSuggestions: [MKLocalSearchCompletion] = []
    @State private var showSuggestions = false
    @State private var debounceWorkItem: DispatchWorkItem? = nil
    
    var body: some View {
        Form {
            Section(header: Text("Saved Addresses")) {
                ForEach(tripManager.favoriteAddresses) { fav in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(fav.name).bold()
                        Text(fav.address).font(.caption).foregroundColor(.secondary)
                    }
                }
                .onDelete { offsets in
                    tripManager.removeFavoriteAddress(at: offsets)
                }
            }
            
            Section(header: Text("Add New Address")) {
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
                
                if showSuggestions && !addressSuggestions.isEmpty {
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
                        }
                    }
                }
                
                Button(action: addFavoriteAddress) {
                    Label("Add Address", systemImage: "plus.circle.fill")
                }
                .disabled(newFavoriteName.trimmingCharacters(in: .whitespaces).isEmpty ||
                         newFavoriteAddress.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Favorite Addresses")
        .onReceive(searchCompleter.$suggestions) { suggestions in
            addressSuggestions = suggestions
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
}

struct VehicleManagerView: View {
    let vehicles: [Vehicle]
    @Binding var selectedVehicleID: String
    let onSave: ([Vehicle]) -> Void
    
    @State private var editingVehicles: [Vehicle]
    @State private var showAddVehicle = false
    @State private var newVehicleName = ""
    @State private var newCityMPG = 25.0
    @State private var newHighwayMPG = 32.0
    @State private var newTankCapacity = 15.0
    
    @Environment(\.dismiss) var dismiss
    
    init(vehicles: [Vehicle], selectedVehicleID: Binding<String>, onSave: @escaping ([Vehicle]) -> Void) {
        self.vehicles = vehicles
        self._selectedVehicleID = selectedVehicleID
        self.onSave = onSave
        self._editingVehicles = State(initialValue: vehicles)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Your Vehicles")) {
                    ForEach(editingVehicles) { vehicle in
                        Button(action: {
                            selectedVehicleID = vehicle.id
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(vehicle.name).bold()
                                    HStack(spacing: 12) {
                                        Label("\(Int(vehicle.cityMPG)) city", systemImage: "building.2.fill")
                                            .font(.caption)
                                        Label("\(Int(vehicle.highwayMPG)) hwy", systemImage: "road.lanes")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.secondary)
                                }
                                Spacer()
                                if vehicle.id == selectedVehicleID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        editingVehicles.remove(atOffsets: offsets)
                    }
                }
                
                Section {
                    Button(action: { showAddVehicle = true }) {
                        Label("Add Vehicle", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Vehicles")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(editingVehicles)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAddVehicle) {
                NavigationView {
                    Form {
                        Section(header: Text("Vehicle Details")) {
                            TextField("Name (e.g. Honda Civic)", text: $newVehicleName)
                            
                            HStack {
                                Text("City MPG")
                                Spacer()
                                TextField("25", value: $newCityMPG, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                            }
                            
                            HStack {
                                Text("Highway MPG")
                                Spacer()
                                TextField("32", value: $newHighwayMPG, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                            }
                            
                            HStack {
                                Text("Tank Capacity (gal)")
                                Spacer()
                                TextField("15", value: $newTankCapacity, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                            }
                        }
                    }
                    .navigationTitle("Add Vehicle")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") { showAddVehicle = false }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Add") {
                                let newVehicle = Vehicle(
                                    name: newVehicleName,
                                    cityMPG: newCityMPG,
                                    highwayMPG: newHighwayMPG,
                                    fuelTankCapacity: newTankCapacity
                                )
                                editingVehicles.append(newVehicle)
                                newVehicleName = ""
                                newCityMPG = 25.0
                                newHighwayMPG = 32.0
                                newTankCapacity = 15.0
                                showAddVehicle = false
                            }
                            .disabled(newVehicleName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
            }
        }
    }
}

struct PrivacySettingsView: View {
    @StateObject private var locationPermission = LocationPermissionManager()
    @StateObject private var motionPermission = MotionPermissionManager()
    @StateObject private var microphonePermission = MicrophonePermissionManager()
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Permissions")) {
                    HStack {
                        Label("Location", systemImage: "location.fill")
                        Spacer()
                        Text(locationStatusText)
                            .foregroundColor(locationAuthorized ? .green : .red)
                        if !locationAuthorized {
                            Button("Allow") { locationPermission.request() }
                                .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    
                    HStack {
                        Label("Motion", systemImage: "figure.walk")
                        Spacer()
                        Text(motionStatusText)
                            .foregroundColor(motionAuthorized ? .green : .red)
                        if !motionAuthorized {
                            Button("Allow") { motionPermission.request() }
                                .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    
                    HStack {
                        Label("Microphone", systemImage: "mic.fill")
                        Spacer()
                        Text(microphoneStatusText)
                            .foregroundColor(microphoneAuthorized ? .green : .red)
                        if !microphoneAuthorized {
                            Button("Allow") { microphonePermission.request() }
                                .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }
                
                Section(footer: Text("These permissions are required for full app functionality. Location is needed for tracking trips, Motion for automatic trip detection, and Microphone for voice navigation.")) {
                    Button(action: openAppSettings) {
                        Label("Open Settings App", systemImage: "gear")
                    }
                }
            }
            .navigationTitle("Permissions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var locationAuthorized: Bool {
        switch locationPermission.status {
        case .authorizedAlways, .authorizedWhenInUse: return true
        default: return false
        }
    }
    
    private var locationStatusText: String {
        switch locationPermission.status {
        case .notDetermined: return "Not Set"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "While Using"
        @unknown default: return "Unknown"
        }
    }
    
    private var motionAuthorized: Bool {
        motionPermission.status == .authorized
    }
    
    private var motionStatusText: String {
        switch motionPermission.status {
        case .notDetermined: return "Not Set"
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
        case .undetermined: return "Not Set"
        case .denied: return "Denied"
        case .granted: return "Authorized"
        @unknown default: return "Unknown"
        }
    }
    
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct BypassCodeView: View {
    @Binding var isPresented: Bool
    @Binding var showJamesDrozImage: Bool
    @State private var bypassCodeInput = ""
    @State private var bypassErrorMessage: String? = nil
    
    var body: some View {
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
            TextField("Bypass Code", text: $bypassCodeInput)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding()
            if let error = bypassErrorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
            HStack(spacing: 20) {
                Button("Submit") {
                    if bypassCodeInput == "unlockpremium" {
                        PremiumManager.shared.isPremium = true
                        UserDefaults.standard.set(true, forKey: "hasPremium")
                        isPresented = false
                        bypassCodeInput = ""
                        bypassErrorMessage = nil
                    } else if bypassCodeInput == "lockpremium" {
                        PremiumManager.shared.isPremium = false
                        UserDefaults.standard.set(false, forKey: "hasPremium")
                        isPresented = false
                        bypassCodeInput = ""
                        bypassErrorMessage = nil
                    } else if bypassCodeInput == "jamesdroz" {
                        isPresented = false
                        bypassCodeInput = ""
                        bypassErrorMessage = nil
                        showJamesDrozImage = true
                    } else {
                        bypassErrorMessage = "Incorrect code."
                    }
                }
                Button("Cancel") {
                    isPresented = false
                    bypassCodeInput = ""
                    bypassErrorMessage = nil
                }
            }
        }
        .padding()
        .frame(maxWidth: 400)
    }
}

struct DataManagementView: View {
    @EnvironmentObject var tripManager: TripManager
    @AppStorage("useKilometers") private var useKilometers: Bool = false
    @AppStorage("autoDeleteTripsAfterDays") private var autoDeleteTripsAfterDays: Int = 0
    
    @Environment(\.dismiss) var dismiss
    @State private var showExportSuccess = false
    @State private var exportMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Trip Statistics")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Trips")
                                .foregroundColor(.secondary)
                            Text("\(tripManager.trips.count)")
                                .font(.title)
                                .bold()
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Distance")
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f %@",
                                       tripManager.trips.reduce(0) { $0 + $1.distance },
                                       useKilometers ? "km" : "mi"))
                                .font(.title)
                                .bold()
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Export Data")) {
                    Button(action: exportAsCSV) {
                        Label("Export as CSV", systemImage: "doc.text.fill")
                    }
                    Button(action: exportAsJSON) {
                        Label("Backup Data (JSON)", systemImage: "doc.badge.arrow.up.fill")
                    }
                    Button(action: exportAsGPX) {
                        Label("Export as GPX", systemImage: "location.fill")
                    }
                }
                
                Section(header: Text("Import Data")) {
                    Button(action: {}) {
                        Label("Restore from Backup", systemImage: "arrow.down.doc.fill")
                    }
                }
                
                Section(header: Text("Auto-Delete")) {
                    Picker("Delete trips after", selection: $autoDeleteTripsAfterDays) {
                        Text("Never").tag(0)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                        Text("6 months").tag(180)
                        Text("1 year").tag(365)
                    }
                    
                    if autoDeleteTripsAfterDays > 0 {
                        Text("Trips older than \(autoDeleteTripsAfterDays) days will be automatically deleted")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Section(header: Text("Storage")) {
                    HStack {
                        Text("App Data Size")
                        Spacer()
                        Text(calculateAppDataSize())
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: clearAllTrips) {
                        Label("Delete All Trips", systemImage: "trash.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Data Management")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Export Complete", isPresented: $showExportSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportMessage)
            }
        }
    }
    
    private func exportAsCSV() {
        let csvString = generateTripCSV()
        shareContent(csvString, filename: "waylon_trips_\(formattedDate()).csv")
        exportMessage = "Trips exported as CSV"
        showExportSuccess = true
    }
    
    private func exportAsJSON() {
        guard let jsonData = try? JSONEncoder().encode(tripManager.trips),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        shareContent(jsonString, filename: "waylon_backup_\(formattedDate()).json")
        exportMessage = "Backup created successfully"
        showExportSuccess = true
    }
    
    private func exportAsGPX() {
        let gpxString = generateGPX()
        shareContent(gpxString, filename: "waylon_trips_\(formattedDate()).gpx")
        exportMessage = "Trips exported as GPX"
        showExportSuccess = true
    }
    
    private func generateTripCSV() -> String {
        // Local formatters to avoid relying on unknown Trip string fields
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        func safeString(_ value: String?) -> String { value ?? "" }

        var csv = "Date,Start Time,End Time,Distance,Duration,Category,Start Address,End Address,Notes\n"
        for trip in tripManager.trips {
            // Try to infer commonly available properties. We assume Trip likely has start and end Date properties named
            // `start`/`end` or a single `date`. We compute strings defensively.
            var dateString = ""
            var startTimeString = ""
            var endTimeString = ""
            var durationString = ""

            // Reflect over potential common property names without using reflection APIs, just optional chaining patterns.
            // We'll use Swift optional casting via key paths not available here, so do a sequence of if-lets by accessing
            // known likely names using Mirror.
            let mirror = Mirror(reflecting: trip)
            var startDateValue: Date? = nil
            var endDateValue: Date? = nil
            var singleDateValue: Date? = nil

            for child in mirror.children {
                switch child.label {
                case "startDate", "start":
                    startDateValue = child.value as? Date
                case "endDate", "end":
                    endDateValue = child.value as? Date
                case "date":
                    singleDateValue = child.value as? Date
                default:
                    break
                }
            }

            if let start = startDateValue {
                dateString = dateFormatter.string(from: start)
                startTimeString = timeFormatter.string(from: start)
            } else if let date = singleDateValue {
                dateString = dateFormatter.string(from: date)
            }

            if let end = endDateValue {
                endTimeString = timeFormatter.string(from: end)
            }

            if let start = startDateValue, let end = endDateValue {
                let duration = end.timeIntervalSince(start)
                if duration > 0 {
                    let minutes = Int(duration / 60)
                    let hours = minutes / 60
                    let mins = minutes % 60
                    durationString = hours > 0 ? String(format: "%dh %dm", hours, mins) : String(format: "%dm", mins)
                }
            }

            let distance = String(format: "%.2f", trip.distance)
            let category = safeString((Mirror(reflecting: trip).children.first { $0.label == "category" }?.value as? String) ?? "")
            let startAddress = safeString((Mirror(reflecting: trip).children.first { $0.label == "startAddress" }?.value as? String) ?? "")
            let endAddress = safeString((Mirror(reflecting: trip).children.first { $0.label == "endAddress" }?.value as? String) ?? "")
            let notesRaw: String = {
                if let n = Mirror(reflecting: trip).children.first(where: { $0.label == "notes" })?.value as? String { return n }
                if let nOpt = Mirror(reflecting: trip).children.first(where: { $0.label == "notes" })?.value as? String? { return nOpt ?? "" }
                return ""
            }()
            let notes = notesRaw.replacingOccurrences(of: "\"", with: "\"\"")

            let row = "\"\(dateString)\",\"\(startTimeString)\",\"\(endTimeString)\",\(distance),\(durationString.isEmpty ? "" : durationString),\"\(category)\",\"\(startAddress)\",\"\(endAddress)\",\"\(notes)\"\n"
            csv += row
        }
        return csv
    }
    
    private func generateGPX() -> String {
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="WaylonApp">
        <metadata>
        <name>Waylon Trips Export</name>
        <time>\(ISO8601DateFormatter().string(from: Date()))</time>
        </metadata>
        
        """
        
        for (index, trip) in tripManager.trips.enumerated() {
            // Safely derive a category string (Trip may not have a `category` member)
            let categoryString: String = {
                let mirror = Mirror(reflecting: trip)
                if let cat = mirror.children.first(where: { $0.label == "category" })?.value as? String {
                    return cat
                }
                if let catOpt = mirror.children.first(where: { $0.label == "category" })?.value as? String? {
                    return catOpt ?? "Uncategorized"
                }
                return "Uncategorized"
            }()
            
            gpx += """
            <trk>
            <name>Trip \(index + 1) - \(categoryString)</name>
            <trkseg>
            
            """
            
            // Add route points if available
            for point in trip.routeCoordinates {
                gpx += "<trkpt lat=\"\(point.latitude)\" lon=\"\(point.longitude)\"></trkpt>\n"
            }
            
            gpx += """
            </trkseg>
            </trk>
            
            """
        }
        
        gpx += "</gpx>"
        return gpx
    }
    
    private func shareContent(_ content: String, filename: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? content.write(to: tempURL, atomically: true, encoding: .utf8)
        
        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func calculateAppDataSize() -> String {
        // Estimate based on trip count (rough calculation)
        let estimatedBytes = tripManager.trips.count * 2000 // ~2KB per trip
        if estimatedBytes < 1024 {
            return "\(estimatedBytes) bytes"
        } else if estimatedBytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(estimatedBytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(estimatedBytes) / (1024.0 * 1024.0))
        }
    }
    
    private func clearAllTrips() {
        tripManager.trips.removeAll()
    }
}

// MARK: - Category Manager View
struct CategoryManagerView: View {
    @AppStorage("tripCategories") private var tripCategoriesData: String = ""
    @AppStorage("defaultTripCategory") private var defaultTripCategory: String = "Business"
    
    @Environment(\.dismiss) var dismiss
    @State private var categories: [String] = []
    @State private var newCategoryName = ""
    @State private var editingCategory: String?
    @State private var editingName = ""
    
    private let defaultCategories = ["Business", "Personal", "Vacation", "Photography", "DoorDash", "Uber"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Categories")) {
                    ForEach(categories.filter { $0 != "Other" }, id: \.self) { category in
                        HStack {
                            if editingCategory == category {
                                TextField("Category name", text: $editingName, onCommit: {
                                    saveEdit(oldName: category)
                                })
                                .textFieldStyle(.roundedBorder)
                            } else {
                                Text(category)
                                Spacer()
                                if !defaultCategories.contains(category) || category != "Other" {
                                    Button(action: {
                                        editingCategory = category
                                        editingName = category
                                    }) {
                                        Image(systemName: "pencil")
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        deleteCategories(at: offsets)
                    }
                    
                    // Other category (always last, can't be deleted)
                    HStack {
                        Text("Other")
                        Spacer()
                        Image(systemName: "lock.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section(header: Text("Add Category")) {
                    HStack {
                        TextField("New category name", text: $newCategoryName)
                        Button(action: addCategory) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                
                Section(footer: Text("Categories help you organize your trips. The 'Other' category cannot be deleted.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Manage Categories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveCategories(categories)
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCategories()
            }
        }
    }
    
    private func loadCategories() {
        let data = Data(tripCategoriesData.utf8)
        if let decoded = try? JSONDecoder().decode([String].self, from: data), !decoded.isEmpty {
            categories = decoded
        } else {
            categories = defaultCategories + ["Other"]
        }
    }
    
    private func addCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !categories.contains(trimmed) else { return }
        categories.insert(trimmed, at: categories.count - 1) // Insert before "Other"
        newCategoryName = ""
    }
    
    private func deleteCategories(at offsets: IndexSet) {
        let filteredCategories = categories.filter { $0 != "Other" }
        var toDelete: [String] = []
        for index in offsets {
            toDelete.append(filteredCategories[index])
        }
        categories.removeAll { toDelete.contains($0) }
        
        // If default category was deleted, reset to "Other"
        if toDelete.contains(defaultTripCategory) {
            defaultTripCategory = "Other"
        }
    }
    
    private func saveEdit(oldName: String) {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, let index = categories.firstIndex(of: oldName) {
            categories[index] = trimmed
            if defaultTripCategory == oldName {
                defaultTripCategory = trimmed
            }
        }
        editingCategory = nil
        editingName = ""
    }
    
    private func saveCategories(_ cats: [String]) {
        var all = Array(Set(cats))
        if !all.contains("Other") {
            all.append("Other")
        }
        all = all.filter { $0 != "Other" }.sorted() + ["Other"]
        if let data = try? JSONEncoder().encode(all) {
            tripCategoriesData = String(data: data, encoding: .utf8) ?? tripCategoriesData
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(TripManager())
        .environmentObject(PremiumManager.shared)
}
