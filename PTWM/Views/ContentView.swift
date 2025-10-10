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
    private static var didSetInitialTab = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @AppStorage("userFirstName") private var userFirstName: String = ""
    @AppStorage("appDarkMode") private var appDarkMode: Bool = false
    @AppStorage("selectedTabIndex") private var selectedTabIndex: Int = 0
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var tripManager = TripManager()
    @State private var showTutorial = false

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

                TabView(selection: $selectedTabIndex) {
                    ExpressRideView()
                        .tabItem {
                            Image(systemName: "car")
                            Text("Map")
                        }
                        .tag(0)

                    NavigationStack {
                        TripLogView()
                    }
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("Trip Log")
                    }
                    .tag(1)

                    MileageReportView()
                        .environmentObject(tripManager)
                        .tabItem {
                            Image(systemName: "chart.bar.doc.horizontal")
                            Text("Mileage Report")
                        }
                        .tag(2)

                    AchievementsView()
                        .environmentObject(tripManager)
                        .tabItem {
                            Image(systemName: "rosette")
                            Text("Achievements")
                        }
                        .tag(3)

                    SettingsView()
                        .environmentObject(tripManager)
                        .tabItem {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                        .tag(4)
                }
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .environmentObject(tripManager)
            }
        }
        .preferredColorScheme(appDarkMode ? .dark : .light)
        .onAppear {
            if !ContentView.didSetInitialTab {
                selectedTabIndex = 0
                ContentView.didSetInitialTab = true
            }

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
            OnboardingView(onDismiss: { hasSeenOnboarding = true }, showTutorial: $showTutorial)
        }
        .fullScreenCover(isPresented: $showTutorial) {
            TutorialScreenPage()
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
