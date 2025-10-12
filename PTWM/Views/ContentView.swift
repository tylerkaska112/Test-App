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
    // MARK: - Static Properties
    private static var didSetInitialTab = false
    
    // MARK: - App Storage
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @AppStorage("userFirstName") private var userFirstName: String = ""
    @AppStorage("appDarkMode") private var appDarkMode: Bool = false
    @AppStorage("selectedTabIndex") private var selectedTabIndex: Int = 0
    
    // MARK: - Environment & State
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var tripManager = TripManager()
    @State private var showTutorial = false
    @State private var isTabBarVisible = true
    @State private var showPermissionAlert = false
    
    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottom) {
            // Welcome banner overlay
            if !showingOnboarding {
                VStack {
                    WelcomeBackBanner()
                        .zIndex(2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
            }
            
            // Main tab view
            TabView(selection: $selectedTabIndex) {
                ExpressRideView()
                    .tabItem {
                        Label("Map", systemImage: "car.fill")
                    }
                    .tag(0)
                
                NavigationStack {
                    TripLogView()
                }
                .tabItem {
                    Label("Trip Log", systemImage: "list.bullet.rectangle")
                }
                .tag(1)
                
                MileageReportView()
                    .environmentObject(tripManager)
                    .tabItem {
                        Label("Reports", systemImage: "chart.bar.doc.horizontal.fill")
                    }
                    .tag(2)
                
                AchievementsView()
                    .environmentObject(tripManager)
                    .tabItem {
                        Label("Achievements", systemImage: "trophy.fill")
                    }
                    .tag(3)
                
                SettingsView()
                    .environmentObject(tripManager)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(4)
            }
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .environmentObject(tripManager)
            .animation(.easeInOut, value: selectedTabIndex)
        }
        .preferredColorScheme(appDarkMode ? .dark : .light)
        .onAppear(perform: setupInitialState)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .fullScreenCover(isPresented: onboardingBinding) {
            OnboardingView(onDismiss: {
                withAnimation {
                    hasSeenOnboarding = true
                }
            }, showTutorial: $showTutorial)
        }
        .fullScreenCover(isPresented: $showTutorial) {
            TutorialScreenPage()
        }
        .alert("Location Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This app needs location access to track your trips. Please enable it in Settings.")
        }
    }
    
    // MARK: - Computed Properties
    private var showingOnboarding: Bool {
        !hasSeenOnboarding
    }
    
    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !hasSeenOnboarding },
            set: { if !$0 { hasSeenOnboarding = true } }
        )
    }
    
    // MARK: - Methods
    private func setupInitialState() {
        // Set initial tab only once
        if !ContentView.didSetInitialTab {
            selectedTabIndex = 0
            ContentView.didSetInitialTab = true
        }
        
        // Configure tab bar appearance
        configureTabBarAppearance()
        
        // Request location permission with user-friendly handling
        requestLocationPermissionWithFeedback()
    }
    
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = nil
        
        // Add subtle shadow for better visual separation
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.1)
        
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    private func requestLocationPermissionWithFeedback() {
        tripManager.requestLocationPermission()
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App became active - good time to refresh if needed
            break
        case .background:
            // App went to background
            break
        default:
            break
        }
    }
    
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    @AppStorage("appDarkMode") private static var appDarkMode: Bool = false
    
    static var previews: some View {
        Group {
            ContentView()
                .preferredColorScheme(appDarkMode ? .dark : .light)
                .previewDisplayName("Current Theme")
            
            ContentView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
            
            ContentView()
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
        }
    }
}
