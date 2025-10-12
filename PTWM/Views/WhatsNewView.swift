import SwiftUI

// MARK: - Models
struct ReleaseNote: Identifiable {
    let id = UUID()
    let text: String
    let icon: String
    let category: NoteCategory
}

enum NoteCategory {
    case new, improved, fixed
    
    var title: String {
        switch self {
        case .new: return "New Features"
        case .improved: return "Improvements"
        case .fixed: return "Bug Fixes"
        }
    }
    
    var color: Color {
        switch self {
        case .new: return .blue
        case .improved: return .green
        case .fixed: return .orange
        }
    }
}

// MARK: - Main View
struct WhatsNewView: View {
    let currentVersion: String
    let onDismiss: () -> Void
    @State private var showAgain = true
    
    private let releaseNotes: [ReleaseNote] = [
        // New Features
        ReleaseNote(text: "Import past trips from CSV/JSON files", icon: "square.and.arrow.down", category: .new),
        ReleaseNote(text: "Export trip data in CSV and JSON formats from mileage reports", icon: "square.and.arrow.up", category: .new),
        ReleaseNote(text: "Trip summary section showing total trips, distance, and averages", icon: "chart.bar", category: .new),
        ReleaseNote(text: "View all unlocked achievements with new filter button", icon: "trophy", category: .new),
        ReleaseNote(text: "Trip end confirmation to prevent accidental stops", icon: "checkmark.shield", category: .new),
        
        // Improvements
        ReleaseNote(text: "Refreshed UI with better overall look and feel", icon: "paintbrush", category: .improved),
        ReleaseNote(text: "Enhanced achievements system for more engaging experience", icon: "star", category: .improved),
        ReleaseNote(text: "Search functionality added to Settings and Achievements", icon: "magnifyingglass", category: .improved),
        
        // Bug Fixes
        ReleaseNote(text: "Optimized trip processing logic for better performance", icon: "gearshape.2", category: .fixed),
        ReleaseNote(text: "General stability improvements and smoother operation", icon: "speedometer", category: .fixed)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Release Notes by Category
                    ForEach([NoteCategory.new, .improved, .fixed], id: \.title) { category in
                        categorySection(for: category)
                    }
                    
                    // Footer with toggle
                    footerSection
                }
                .padding()
            }
            .navigationTitle("What's New")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        // Save preference if needed
                        if !showAgain {
                            UserDefaults.standard.set(currentVersion, forKey: "lastSeenWhatsNewVersion")
                        }
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Subviews
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundStyle(.blue.gradient)
            
            Text("Version \(currentVersion)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Here's what's new in this update")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
    
    private func categorySection(for category: NoteCategory) -> some View {
        let notes = releaseNotes.filter { $0.category == category }
        
        return VStack(alignment: .leading, spacing: 12) {
            if !notes.isEmpty {
                HStack {
                    Circle()
                        .fill(category.color)
                        .frame(width: 8, height: 8)
                    
                    Text(category.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(notes) { note in
                        noteRow(note: note)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func noteRow(note: ReleaseNote) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: note.icon)
                .font(.system(size: 16))
                .foregroundColor(note.category.color)
                .frame(width: 24)
            
            Text(note.text)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(.leading, 8)
    }
    
    private var footerSection: some View {
        VStack(spacing: 16) {
            Divider()
            
            Toggle(isOn: $showAgain) {
                Text("Show release notes on updates")
                    .font(.subheadline)
            }
            .tint(.blue)
            
            Text("Thank you for using the app!")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    WhatsNewView(currentVersion: "2.4.0", onDismiss: {})
}
#endif
