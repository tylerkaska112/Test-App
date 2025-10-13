//
//  BackgroundWrapper.swift
//  waylon
//
//  Created by tyler kaska on 6/26/25.
//

import SwiftUI

struct BackgroundWrapper<Content: View>: View {
    @EnvironmentObject var tripManager: TripManager
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            backgroundLayer
            content
        }
    }
    
    @ViewBuilder
    private var backgroundLayer: some View {
        if let image = tripManager.backgroundImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .accessibilityHidden(true)
        } else {
            Color(.systemBackground)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Preview Provider
#Preview {
    BackgroundWrapper {
        VStack {
            Text("Sample Content")
                .font(.largeTitle)
            Text("Background wrapper demo")
                .foregroundStyle(.secondary)
        }
    }
    .environmentObject(TripManager())
}
