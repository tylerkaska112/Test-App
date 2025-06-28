//
//  ContentView.swift
//  waylon
//
//  Created by tyler kaska on 6/26/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var tripManager = TripManager()
    @State private var showInfo = false

    var body: some View {
        TabView {
            NavigationStack {
                TripTrackerView()
                    .navigationTitle("Start Trip")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                showInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                            }
                        }
                    }
            }
            .tabItem {
                Image(systemName: "car.fill")
                Text("Trip")
            }

            NavigationStack {
                TripLogView()
                    .navigationTitle("Trip Log")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                showInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                            }
                        }
                    }
            }
            .tabItem {
                Image(systemName: "list.bullet")
                Text("Log")
            }

            NavigationStack {
                BackgroundView()
                    .navigationTitle("Background")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                showInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                            }
                        }
                    }
            }
            .tabItem {
                Image(systemName: "photo")
                Text("Background")
            }
        }
        .sheet(isPresented: $showInfo) {
            InfoView()
        }
        .environmentObject(tripManager)
        .onAppear {
            tripManager.requestLocationPermission()
        }
    }
}

struct BackgroundView: View {
    @EnvironmentObject var tripManager: TripManager
    @State private var showImagePicker = false

    var body: some View {
        VStack(spacing: 20) {
            Button("Change Background") {
                showImagePicker = true
            }
            .padding()

            Button("Remove Background") {
                tripManager.removeBackgroundImage()
            }
            .padding()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker { image in
                tripManager.setBackgroundImage(image)
            }
        }
    }
}
