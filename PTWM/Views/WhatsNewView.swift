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
        ReleaseNote(text: "Import your trip history from CSV or JSON files seamlessly", icon: "arrow.down.doc", category: .new),
        ReleaseNote(text: "Export any trip as a GPX file for use with other mapping apps", icon: "arrow.up.doc", category: .new),
        ReleaseNote(text: "Export trips as MP4 videos to share your journeys visually", icon: "video.fill", category: .new),
        ReleaseNote(text: "View comprehensive trip statistics including total distance and averages", icon: "chart.bar.fill", category: .new),
        ReleaseNote(text: "Browse and filter all your unlocked achievements in one place", icon: "trophy.fill", category: .new),
        ReleaseNote(text: "See distance to locations when searching and browsing places", icon: "location.circle.fill", category: .new),
        ReleaseNote(text: "Confirm trip endings with a safety prompt to avoid accidental stops", icon: "hand.raised.fill", category: .new),
        ReleaseNote(text: "Scrub through trip timelines to replay any moment from your journey", icon: "slider.horizontal.3", category: .new),
        ReleaseNote(text: "Unlock exciting new achievements and level up your driving experience", icon: "medal.fill", category: .new),
        ReleaseNote(text: "Enable performance saver mode to optimize battery and data usage", icon: "battery.100.bolt", category: .new),
        ReleaseNote(text: "Calculate expenses using the official IRS mileage rate for businesses", icon: "dollarsign.circle.fill", category: .new),
        ReleaseNote(text: "Protect your privacy by blurring saved home and work locations on maps", icon: "eye.slash.fill", category: .new),
        ReleaseNote(text: "Manage app storage with the new data and storage section in settings", icon: "internaldrive.fill", category: .new),
        ReleaseNote(text: "Customize text size throughout the app for better readability", icon: "textformat.size", category: .new),
        ReleaseNote(text: "Stay safe with speed warnings that alert you when driving too fast", icon: "exclamationmark.triangle.fill", category: .new),
        ReleaseNote(text: "Filter and search through your trip logs to find exactly what you need", icon: "line.3.horizontal.decrease.circle.fill", category: .new),
        
        // Improvements
        ReleaseNote(text: "The app is now completely free with no subscriptions required! 🎉", icon: "gift.fill", category: .improved),
        ReleaseNote(text: "Redesigned interface with modern styling and improved usability", icon: "paintbrush.fill", category: .improved),
        ReleaseNote(text: "Upgraded achievements system with better progression and rewards", icon: "star.fill", category: .improved),
        ReleaseNote(text: "Quickly find any setting or achievement with new search functionality", icon: "magnifyingglass", category: .improved),
        
        // Bug Fixes
        ReleaseNote(text: "Trip log statistics now calculate and display correctly", icon: "chart.line.uptrend.xyaxis", category: .fixed),
        ReleaseNote(text: "Speed tracking data now appears properly in all trip logs", icon: "speedometer", category: .fixed),
        ReleaseNote(text: "All accessibility features in settings are now fully functional", icon: "accessibility", category: .fixed),
        ReleaseNote(text: "Improved trip processing performance for smoother operation", icon: "bolt.fill", category: .fixed),
        ReleaseNote(text: "Enhanced overall stability and eliminated common crashes", icon: "checkmark.shield.fill", category: .fixed)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    ForEach([NoteCategory.new, .improved, .fixed], id: \.title) { category in
                        categorySection(for: category)
                    }
                    
                    footerSection
                }
                .padding()
            }
            .navigationTitle("What's New")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
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
    WhatsNewView(currentVersion: "3.1.0", onDismiss: {})
}
#endif
