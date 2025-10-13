//
//  PTWMApp.swift
//  PTWM
//
//  Created by tyler kaska on 6/26/25.
//

import SwiftUI

@main
struct PTWMApp: App {
    @StateObject private var appSettings = AppSettings()
    
    init() {
        configureDefaultSettings()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
                .preferredColorScheme(appSettings.isDarkMode ? .dark : .light)
        }
    }
    
    // MARK: - Private Methods
    
    private func configureDefaultSettings() {
        let defaults = UserDefaults.standard
        
        // Register default values if not already set
        if defaults.object(forKey: UserDefaultsKeys.appDarkMode) == nil {
            defaults.set(true, forKey: UserDefaultsKeys.appDarkMode)
        }
    }
}

// MARK: - App Settings

class AppSettings: ObservableObject {
    @AppStorage(UserDefaultsKeys.appDarkMode) var isDarkMode: Bool = true
}

// MARK: - Constants

struct UserDefaultsKeys {
    static let appDarkMode = "appDarkMode"
}
