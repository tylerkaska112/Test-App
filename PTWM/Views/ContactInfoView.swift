//  ContactInfoView.swift
//  waylon
//
//  Created by Assistant on 6/30/25.
//

import SwiftUI

struct ContactInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Email: Linemen1209@gmail.com")
                Link("Visit GitHub", destination: URL(string: "https://github.com/tylerkaska112")!)
                Spacer()
            }
            .padding()
            .navigationTitle("Contact Info")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContactInfoView()
}
