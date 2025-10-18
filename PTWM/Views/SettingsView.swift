import SwiftUI
import CoreLocation
import AVFoundation
import CoreMotion
import UIKit
import MapKit
import UserNotifications
import StoreKit
import LocalAuthentication

// MARK: - Main Settings View (Simplified Navigation Hub)

struct SettingsView: View {
    @EnvironmentObject var tripManager: TripManager
    @AppStorage("userFirstName") private var userFirstName: String = ""
    @AppStorage("hasPremium") private var hasPremium: Bool = false
    
    @State private var showAbout = false
    @State private var showContact = false
    @State private var showWhatsNew = false
    @State private var showBypassSheet = false
    @State private var showJamesDrozImage = false
    @State private var showOnboardingDebug = false
    @State private var showTutorialDebug = false
    @State private var showTutorial: Bool = false
    
    private var appVersion: String {
        let dict = Bundle.main.infoDictionary
        let version = dict?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = dict?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    var body: some View {
        BackgroundWrapper {
            NavigationView {
                ScrollView {
                    VStack(spacing: 20) {
                        profileHeader
                        
                        VStack(spacing: 12) {
                            NavigationLink(destination: TripSettingsView()) {
                                SettingsGroupCard(
                                    icon: "car.fill",
                                    title: "Trip & Tracking",
                                    subtitle: "Auto-detection, categories, tracking",
                                    color: .blue
                                )
                            }
                            
                            NavigationLink(destination: VehicleSettingsView()) {
                                SettingsGroupCard(
                                    icon: "fuelpump.fill",
                                    title: "Vehicle & Fuel",
                                    subtitle: "Vehicles, MPG, fuel prices",
                                    color: .orange
                                )
                            }
                            
                            NavigationLink(destination: MapNavigationSettingsView()) {
                                SettingsGroupCard(
                                    icon: "map.fill",
                                    title: "Map & Navigation",
                                    subtitle: "Map style, voice, speed warnings",
                                    color: .green
                                )
                            }
                            
                            NavigationLink(destination: AppearanceSettingsView()) {
                                SettingsGroupCard(
                                    icon: "paintbrush.fill",
                                    title: "Appearance",
                                    subtitle: "Theme, units, text size",
                                    color: .purple
                                )
                            }
                            
                            NavigationLink(destination: PrivacySecuritySettingsView()) {
                                SettingsGroupCard(
                                    icon: "lock.shield.fill",
                                    title: "Privacy & Security",
                                    subtitle: "Permissions, trip log protection",
                                    color: .red
                                )
                            }
                            
                            NavigationLink(destination: DataStorageSettingsView()) {
                                SettingsGroupCard(
                                    icon: "externaldrive.fill",
                                    title: "Data & Storage",
                                    subtitle: "Export, backup, manage storage",
                                    color: .cyan,
                                    badge: "\(tripManager.trips.count)"
                                )
                            }
                            
                            NavigationLink(destination: PerformanceSettingsView()) {
                                SettingsGroupCard(
                                    icon: "bolt.fill",
                                    title: "Performance",
                                    subtitle: "Battery, GPS accuracy",
                                    color: .yellow
                                )
                            }
                        }
                        
                        quickActionsSection
                        
                        aboutSection
                    }
                    .padding()
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .navigationTitle("Settings")
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Menu {
                            Button(action: { showWhatsNew = true }) {
                                Label("What's New", systemImage: "sparkles")
                            }
                            Divider()
                            Menu("Developer", systemImage: "wrench.and.screwdriver") {
                                Button(action: { showBypassSheet = true }) {
                                    Label("Bypass / Premium", systemImage: "key.fill")
                                }
                                Divider()
                                Button(action: { showOnboardingDebug = true }) {
                                    Label("Present Onboarding", systemImage: "play.rectangle.fill")
                                }
                                Button(action: { showTutorialDebug = true }) {
                                    Label("Present Tutorial Screens", systemImage: "book.pages.fill")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
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
                .sheet(isPresented: $showOnboardingDebug) {
                    OnboardingView(onDismiss: { showOnboardingDebug = false }, showTutorial: $showTutorial)
                }
                .sheet(isPresented: $showTutorialDebug) {
                    TutorialScreenPage()
                }
                .sheet(isPresented: $showAbout) {
                    InfoView()
                }
                .sheet(isPresented: $showContact) {
                    ContactInfoView()
                }
            }
        }
    }
    
    private var profileHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                
                Text(userFirstName.prefix(1).uppercased())
                    .font(.title.bold())
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(userFirstName.isEmpty ? "Welcome" : "Hi, \(userFirstName)!")
                    .font(.title2.bold())
                
                HStack(spacing: 4) {
                    Image(systemName: hasPremium ? "crown.fill" : "car.fill")
                        .font(.caption)
                    Text(hasPremium ? "Premium Member" : "Free Version")
                        .font(.subheadline)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            NavigationLink(destination: ProfileSettingsView()) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
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
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                QuickActionButton(icon: "square.and.arrow.up.on.square", title: "Export GPX", action: exportTripData)
                QuickActionButton(icon: "square.and.arrow.up", title: "Share App", action: shareApp)
                QuickActionButton(icon: "trash", title: "Clear Cache", action: clearCache)
            }
        }
    }
    
    private var aboutSection: some View {
        VStack(spacing: 12) {
            Button(action: { showAbout = true }) {
                HStack {
                    Label("About Waylon", systemImage: "info.circle")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { showContact = true }) {
                HStack {
                    Label("Contact Support", systemImage: "envelope")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("Version \(appVersion)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }
    
    private func exportTripData() {
        let gpxString = generateGPX()
        shareContent(gpxString, filename: "waylon_trips_\(Date().ISO8601Format()).gpx")
    }
    
    private func generateGPX() -> String {
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="WaylonApp">
        """
        for trip in tripManager.trips {
            gpx += "<trk><trkseg>"
            for point in trip.routeCoordinates {
                gpx += "<trkpt lat=\"\(point.latitude)\" lon=\"\(point.longitude)\"></trkpt>"
            }
            gpx += "</trkseg></trk>"
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
    
    private func shareApp() {
        let activityVC = UIActivityViewController(
            activityItems: ["Check out Waylon - the best trip tracking app!"],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
    }
}

// MARK: - Settings Group Card Component

struct SettingsGroupCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var badge: String? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if let badge = badge {
                Text(badge)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.2))
                    .cornerRadius(8)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
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

// MARK: - Profile Settings View

struct ProfileSettingsView: View {
    @EnvironmentObject var tripManager: TripManager
    @AppStorage("userFirstName") private var userFirstName: String = ""
    
    var body: some View {
        Form {
            Section(header: Text("Personal Information")) {
                HStack {
                    Text("First Name")
                    Spacer()
                    TextField("Your name", text: $userFirstName)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            Section(header: Text("Favorite Places")) {
                NavigationLink(destination: FavoriteAddressesView()) {
                    HStack {
                        Label("Favorite Addresses", systemImage: "mappin.and.ellipse")
                        Spacer()
                        Text("\(tripManager.favoriteAddresses.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Trip Settings View

struct TripSettingsView: View {
    @AppStorage("defaultTripCategory") private var defaultTripCategory: String = "Business"
    @AppStorage("tripCategories") private var tripCategoriesData: String = ""
    @AppStorage("autoTripDetectionEnabled") private var autoTripDetectionEnabled: Bool = false
    @AppStorage("autoTripSpeedThresholdMPH") private var autoTripSpeedThresholdMPH: Double = 20.0
    @AppStorage("autoTripEndDelaySecs") private var autoTripEndDelaySecs: Double = 180.0
    @AppStorage("minimumTripDistance") private var minimumTripDistance: Double = 0.5
    @AppStorage("useKilometers") private var useKilometers: Bool = false
    
    @State private var showCategoryManager = false
    
    private var categories: [String] {
        let decoded = (try? JSONDecoder().decode([String].self, from: Data(tripCategoriesData.utf8))) ?? []
        var unique = Array(Set(decoded))
        if !unique.contains("Other") {
            unique.append("Other")
        }
        return unique.filter { $0 != "Other" }.sorted() + ["Other"]
    }
    
    var body: some View {
        Form {
            Section(header: Text("Categories")) {
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
            }
            
            Section(header: Text("Auto Trip Detection")) {
                Toggle(isOn: $autoTripDetectionEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto Detection")
                        Text("Start trips automatically")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if autoTripDetectionEnabled {
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
            
            Section(footer: Text("Auto trip detection uses GPS and motion sensors to automatically start and stop tracking when you drive.")) {
                EmptyView()
            }
        }
        .navigationTitle("Trip & Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCategoryManager) {
            CategoryManagerView()
        }
    }
}

// MARK: - Vehicle Settings View

struct VehicleSettingsView: View {
    @AppStorage("cityMPG") private var cityMPG: Double = 25.0
    @AppStorage("highwayMPG") private var highwayMPG: Double = 32.0
    @AppStorage("gasPricePerGallon") private var gasPricePerGallon: Double = 3.99
    @AppStorage("selectedVehicleID") private var selectedVehicleID: String = ""
    @AppStorage("savedVehiclesData") private var savedVehiclesData: String = ""
    @AppStorage("useIRSMileageRate") private var useIRSMileageRate: Bool = false
    @AppStorage("customReimbursementRate") private var customReimbursementRate: Double = 0.67
    
    @State private var showVehicleManager = false
    
    private var vehicles: [Vehicle] {
        let trimmed = savedVehiclesData.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return (try? JSONDecoder().decode([Vehicle].self, from: Data(trimmed.utf8))) ?? []
    }
    
    private var selectedVehicle: Vehicle? {
        vehicles.first { $0.id == selectedVehicleID }
    }
    
    private func saveVehicles(_ vehicles: [Vehicle]) {
        if let data = try? JSONEncoder().encode(vehicles),
           let str = String(data: data, encoding: .utf8) {
            savedVehiclesData = str
        }
    }
    
    var body: some View {
        Form {
            Section(header: Text("Current Vehicle")) {
                if let vehicle = selectedVehicle {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(vehicle.name).font(.headline)
                        HStack(spacing: 16) {
                            Label("\(Int(vehicle.cityMPG)) city", systemImage: "building.2.fill")
                                .font(.caption)
                            Label("\(Int(vehicle.highwayMPG)) hwy", systemImage: "road.lanes")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
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
            }
            
            Section(header: Text("Fuel Costs")) {
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
            }
            
            Section(header: Text("Reimbursement")) {
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
        .navigationTitle("Vehicle & Fuel")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showVehicleManager) {
            VehicleManagerView(vehicles: vehicles, selectedVehicleID: $selectedVehicleID, onSave: saveVehicles)
        }
    }
}

// MARK: - Map & Navigation Settings View

struct MapNavigationSettingsView: View {
    @AppStorage("selectedMapStyle") private var selectedMapStyle: Int = 0
    @AppStorage("showTrafficOnMap") private var showTrafficOnMap: Bool = true
    @AppStorage("showPOIOnMap") private var showPOIOnMap: Bool = true
    @AppStorage("show3DBuildings") private var show3DBuildings: Bool = true
    @AppStorage("showMapCompass") private var showMapCompass: Bool = true
    @AppStorage("showMapScale") private var showMapScale: Bool = false
    @AppStorage("muteSpokenNavigation") private var muteSpokenNavigation: Bool = false
    @AppStorage("speedLimitWarningEnabled") private var speedLimitWarningEnabled: Bool = false
    @AppStorage("speedLimitThreshold") private var speedLimitThreshold: Double = 75.0
    
    @State private var showVoiceOptions = false
    
    var body: some View {
        Form {
            Section(header: Text("Map Display")) {
                Picker("Map Style", selection: $selectedMapStyle) {
                    Text("Standard").tag(0)
                    Text("Satellite").tag(1)
                    Text("Hybrid").tag(2)
                    Text("Muted").tag(3)
                }
                
                Toggle("Show Traffic", isOn: $showTrafficOnMap)
                Toggle("Points of Interest", isOn: $showPOIOnMap)
                Toggle("3D Buildings", isOn: $show3DBuildings)
                Toggle("Compass", isOn: $showMapCompass)
                Toggle("Scale Bar", isOn: $showMapScale)
            }
            
            Section(header: Text("Navigation Voice")) {
                Toggle("Mute Navigation", isOn: $muteSpokenNavigation)
                
                Button(action: { showVoiceOptions = true }) {
                    HStack {
                        Label("Voice Settings", systemImage: "waveform")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            
            Section(header: Text("Speed Warnings")) {
                Toggle("Speed Warnings", isOn: $speedLimitWarningEnabled)
                
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
        .navigationTitle("Map & Navigation")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showVoiceOptions) {
            VoiceOptionsView()
        }
    }
}

// MARK: - Appearance Settings View

struct AppearanceSettingsView: View {
    @AppStorage("appDarkMode") private var appDarkMode: Bool = false
    @AppStorage("useKilometers") private var useKilometers: Bool = false
    @AppStorage("fontSizeMultiplier") private var fontSizeMultiplier: Double = 1.0
    @AppStorage("accentColorName") private var accentColorName: String = "blue"
    
    var body: some View {
        Form {
            Section(header: Text("Theme")) {
                Toggle("Dark Mode", isOn: $appDarkMode)
            }
            
            Section(header: Text("Units")) {
                Toggle("Use Kilometers", isOn: $useKilometers)
            }
            
            Section(header: Text("Text Size")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Size")
                        Spacer()
                        Text("\(Int(fontSizeMultiplier * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $fontSizeMultiplier, in: 0.8...1.4, step: 0.1)
                    
                    Text("Preview: The quick brown fox")
                        .font(.system(size: 16 * fontSizeMultiplier))
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Privacy & Security Settings View

struct PrivacySecuritySettingsView: View {
    @AppStorage("tripLogProtectionEnabled") private var tripLogProtectionEnabled: Bool = false
    @AppStorage("tripLogProtectionMethod") private var tripLogProtectionMethod: String = "biometric"
    @AppStorage("blurHomeLocation") private var blurHomeLocation: Bool = false
    @AppStorage("blurWorkLocation") private var blurWorkLocation: Bool = false
    
    @State private var showPrivacySettings = false
    @State private var showLogLockAuthError = false
    @State private var logLockAuthErrorMessage = ""
    
    var body: some View {
        Form {
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Require Authentication")
                        Text("Protect your trip history")
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
            }
            
            Section(header: Text("Location Privacy")) {
                Toggle("Blur Home Location", isOn: $blurHomeLocation)
                Toggle("Blur Work Location", isOn: $blurWorkLocation)
            }
            
            Section(header: Text("Permissions")) {
                Button(action: { showPrivacySettings = true }) {
                    HStack {
                        Label("Manage Permissions", systemImage: "hand.raised.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("Privacy & Security")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPrivacySettings) {
            PrivacySettingsView()
        }
        .alert("Authentication Error", isPresented: $showLogLockAuthError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(logLockAuthErrorMessage)
        }
    }
    
    private func authenticateBeforeDisablingLogLock() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock to change settings") { success, evalError in
                DispatchQueue.main.async {
                    if success {
                        tripLogProtectionEnabled = false
                    } else {
                        showLogLockAuthError = true
                        logLockAuthErrorMessage = evalError?.localizedDescription ?? "Authentication failed."
                    }
                }
            }
        } else {
            showLogLockAuthError = true
            logLockAuthErrorMessage = "Biometric authentication not available."
        }
    }
}

// MARK: - Data & Storage Settings View

struct DataStorageSettingsView: View {
    @EnvironmentObject var tripManager: TripManager
    @AppStorage("useKilometers") private var useKilometers: Bool = false
    @AppStorage("autoDeleteTripsAfterDays") private var autoDeleteTripsAfterDays: Int = 0
    
    @State private var showExportSuccess = false
    @State private var exportMessage = ""
    @State private var showClearDataAlert = false
    
    private var totalStorageUsed: Int64 {
        StorageCalculator.calculateTripStorageSize(trips: tripManager.trips)
    }
    
    private var storageBreakdown: StorageBreakdown {
        StorageCalculator.storageBreakdown(trips: tripManager.trips)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Trip Statistics")) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Trips")
                            .foregroundColor(.secondary)
                        Text("\(tripManager.trips.count)")
                            .font(.title2.bold())
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Distance")
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f %@",
                                   tripManager.trips.reduce(0) { $0 + $1.distance },
                                   useKilometers ? "km" : "mi"))
                            .font(.title2.bold())
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section(header: Text("Storage Usage")) {
                HStack {
                    Text("Total Storage")
                    Spacer()
                    Text(StorageCalculator.formatBytes(totalStorageUsed))
                        .foregroundColor(.secondary)
                        .bold()
                }
                
                NavigationLink(destination: StorageBreakdownView()) {
                    Label("View Storage Breakdown", systemImage: "chart.bar.fill")
                }
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
            
            Section(header: Text("Danger Zone")) {
                Button(action: { showClearDataAlert = true }) {
                    Label("Delete All Trips", systemImage: "trash.fill")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Data & Storage")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Export Complete", isPresented: $showExportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportMessage)
        }
        .alert("Delete All Trips?", isPresented: $showClearDataAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {
                tripManager.trips.removeAll()
            }
        } message: {
            Text("This will permanently delete all trips, audio notes, and photos. This action cannot be undone.")
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
        var csv = "Date,Distance,Category,Notes\n"
        for trip in tripManager.trips {
            let distance = String(format: "%.2f", trip.distance)
            csv += "\"\(trip.startTime)\",\(distance),\"\",\"\"\n"
        }
        return csv
    }
    
    private func generateGPX() -> String {
        var gpx = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><gpx version=\"1.1\">"
        for trip in tripManager.trips {
            gpx += "<trk><trkseg>"
            for point in trip.routeCoordinates {
                gpx += "<trkpt lat=\"\(point.latitude)\" lon=\"\(point.longitude)\"></trkpt>"
            }
            gpx += "</trkseg></trk>"
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
}

// MARK: - Storage Breakdown View

struct StorageBreakdownView: View {
    @EnvironmentObject var tripManager: TripManager
    
    private var storageBreakdown: StorageBreakdown {
        StorageCalculator.storageBreakdown(trips: tripManager.trips)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Storage Breakdown")) {
                StorageBreakdownRow(
                    icon: "doc.text.fill",
                    label: "Trip Data",
                    size: storageBreakdown.tripData,
                    total: storageBreakdown.total,
                    color: .blue
                )
                
                StorageBreakdownRow(
                    icon: "waveform",
                    label: "Audio Notes",
                    size: storageBreakdown.audioFiles,
                    total: storageBreakdown.total,
                    color: .orange
                )
                
                StorageBreakdownRow(
                    icon: "photo.fill",
                    label: "Photos",
                    size: storageBreakdown.photoFiles,
                    total: storageBreakdown.total,
                    color: .purple
                )
                
                StorageBreakdownRow(
                    icon: "map.fill",
                    label: "Route Data",
                    size: storageBreakdown.routeData,
                    total: storageBreakdown.total,
                    color: .green
                )
            }
            
            Section(header: Text("Quick Stats")) {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("\(tripManager.trips.count)")
                            .font(.headline)
                        Text("Trips")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Divider()
                        .frame(height: 30)
                    Spacer()
                    VStack(spacing: 4) {
                        let audioCount = tripManager.trips.reduce(0) { $0 + $1.audioNotes.count }
                        Text("\(audioCount)")
                            .font(.headline)
                        Text("Audio")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Divider()
                        .frame(height: 30)
                    Spacer()
                    VStack(spacing: 4) {
                        let photoCount = tripManager.trips.reduce(0) { $0 + $1.photoURLs.count }
                        Text("\(photoCount)")
                            .font(.headline)
                        Text("Photos")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Storage Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Performance Settings View

struct PerformanceSettingsView: View {
    @AppStorage("batterySavingMode") private var batterySavingMode: Bool = false
    @AppStorage("gpsAccuracyMeters") private var gpsAccuracyMeters: Double = 10.0
    @AppStorage("enableSpeedTracking") private var enableSpeedTracking: Bool = false
    
    private var accuracyDescription: String {
        switch gpsAccuracyMeters {
        case 0..<15: return "Excellent (Best)"
        case 15..<30: return "Very Good"
        case 30..<50: return "Good"
        case 50..<75: return "Fair"
        default: return "Basic"
        }
    }
    
    private var accuracyColor: Color {
        switch gpsAccuracyMeters {
        case 0..<15: return .green
        case 15..<30: return .blue
        case 30..<50: return .yellow
        case 50..<75: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        Form {
            Section(header: Text("Battery & GPS")) {
                Toggle(isOn: $batterySavingMode) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Battery Saving Mode")
                        Text("Reduced GPS accuracy (~100m)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !batterySavingMode {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("GPS Accuracy")
                            Spacer()
                            Text("\(Int(gpsAccuracyMeters))m")
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        Slider(value: $gpsAccuracyMeters, in: 5...100, step: 5)
                        
                        HStack {
                            Text(accuracyDescription)
                                .font(.caption)
                                .foregroundColor(accuracyColor)
                                .bold()
                            Spacer()
                        }
                        
                        Text("Lower = more accurate, higher battery use")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text("GPS accuracy fixed at 100m")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("Tracking Options")) {
                Toggle(isOn: $enableSpeedTracking) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speed Tracking")
                        Text("Record speed data in trips")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(footer: Text("Lower GPS accuracy values provide more precise location tracking but use more battery. Battery saving mode optimizes for longest battery life.")) {
                EmptyView()
            }
        }
        .navigationTitle("Performance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Supporting Components (kept from original)

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

struct StorageBreakdownRow: View {
    let icon: String
    let label: String
    let size: Int64
    let total: Int64
    let color: Color
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(size) / Double(total)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(StorageCalculator.formatBytes(size))
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * percentage, height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
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

// MARK: - Favorite Addresses View
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

// MARK: - Vehicle Manager View
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

// MARK: - Privacy Settings View
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
        categories.insert(trimmed, at: categories.count - 1)
        newCategoryName = ""
    }
    
    private func deleteCategories(at offsets: IndexSet) {
        let filteredCategories = categories.filter { $0 != "Other" }
        var toDelete: [String] = []
        for index in offsets {
            toDelete.append(filteredCategories[index])
        }
        categories.removeAll { toDelete.contains($0) }
        
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

// MARK: - Bypass Code View
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
                        UserDefaults.standard.set(true, forKey: "hasPremium")
                        isPresented = false
                        bypassCodeInput = ""
                        bypassErrorMessage = nil
                    } else if bypassCodeInput == "lockpremium" {
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

// MARK: - Permission Managers
class LocationPermissionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var status: CLAuthorizationStatus = CLLocationManager.authorizationStatus()
    private let manager = CLLocationManager()
    
    override init() {
        super.init()
        manager.delegate = self
    }
    
    func request() {
        manager.requestWhenInUseAuthorization()
    }
    
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

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(TripManager())
}
