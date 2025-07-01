//
//  JamesDrozImageView.swift
//  waylon
//
//  Created by Tyler Kaska on 6/30/25.
//


import SwiftUI

struct JamesDrozImageView: View {
    var body: some View {
        VStack {
            Spacer()
            Image("JamesDroz")
                .resizable()
                .scaledToFit()
                .padding()
            Spacer()
        }
        .navigationTitle("")
        .background(Color(.systemBackground))
    }
}

#Preview {
    JamesDrozImageView()
}