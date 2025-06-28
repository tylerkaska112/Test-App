//
//  InfoView.swift
//  waylon
//
//  Created by tyler kaska on 6/27/25.
//


import SwiftUI

struct InfoView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Contact Information")
                .font(.title)
                .padding()

            Text("Email: support@example.com")
            Text("Phone: (123) 456-7890")

            Spacer()
        }
        .padding()
    }
}