//
//  ContentView.swift
//  waylonApp
//
//  Created by Waylon on 10/15/21.
//

import SwiftUI
import UIKit
import Charts

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @AppStorage("userFirstName") private var userFirstName: String = ""
    @AppStorage("appDarkMode") private var appDarkMode: Bool = false
    @StateObject var tripManager = TripManager()
    
    var body: some View {
        let showingOnboarding = !hasSeenOnboarding
        
        Group {
            ZStack(alignment: .bottom) {
                VStack {
                    if !showingOnboarding {
                        WelcomeBackBanner()
                            .zIndex(2)
                    }
                    Spacer()
                }
                
                TabView {
                    ExpressRideView()
                        .tabItem {
                            Image(systemName: "car")
                            Text("Map")
                        }
                    
                    MileageReportView()
                        .environmentObject(tripManager)
                        .tabItem {
                            Image(systemName: "chart.bar.doc.horizontal")
                            Text("Mileage Report")
                        }
                    
                    TripLogView()
                        .tabItem {
                            Image(systemName: "list.bullet")
                            Text("Trip Log")
                        }
                    
                    SettingsView()
                        .tabItem {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                }
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .environmentObject(tripManager)
            }
        }
        .preferredColorScheme(appDarkMode ? .dark : .light)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            appearance.backgroundColor = nil
            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
            
            tripManager.requestLocationPermission()
        }
        .fullScreenCover(isPresented: Binding(get: { !hasSeenOnboarding }, set: { if !$0 { hasSeenOnboarding = true } })) {
            OnboardingView {
                hasSeenOnboarding = true
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    @AppStorage("appDarkMode") private static var appDarkMode: Bool = false
    
    static var previews: some View {
        ContentView()
            .preferredColorScheme(appDarkMode ? .dark : .light)
    }
}
