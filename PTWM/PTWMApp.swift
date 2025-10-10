//
//  waylonApp.swift
//  waylon
//
//  Created by tyler kaska on 6/26/25.
//

import SwiftUI

@main
struct PTWMApp: App {
    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "appDarkMode") == nil {
            defaults.set(true, forKey: "appDarkMode")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
