//
//  BackgroundWrapper.swift
//  waylon
//
//  Created by tyler kaska on 6/26/25.
//


import SwiftUI

struct BackgroundWrapper<Content: View>: View {
    @EnvironmentObject var tripManager: TripManager
    let content: () -> Content

    var body: some View {
        ZStack {
            if let image = tripManager.backgroundImage {
                Image(uiImage: image)
                    .resizable()
                    .ignoresSafeArea()
            } else {
                Color(.systemBackground)
                    .ignoresSafeArea()
            }
            content()
        }
    }
}

