//  ContactInfoView.swift
//  waylon
//
//  Created by Assistant on 6/30/25.
//

import SwiftUI

struct ContactInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header Section
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.blue.gradient)
                        
                        Text("Get in Touch")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .padding(.top, 20)
                    
                    // Contact Cards
                    VStack(spacing: 16) {
                        ContactCard(
                            icon: "envelope.fill",
                            title: "Email",
                            content: "Linemen1209@gmail.com",
                            action: {
                                if let url = URL(string: "mailto:Linemen1209@gmail.com") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        )
                        
                        ContactCard(
                            icon: "link.circle.fill",
                            title: "GitHub",
                            content: "@tylerkaska112",
                            action: {
                                if let url = URL(string: "https://github.com/tylerkaska112") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("Contact Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct ContactCard: View {
    let icon: String
    let title: String
    let content: String
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.blue.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text(content)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContactInfoView()
}
