import SwiftUI

struct TutorialScreenPage: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TutorialTabPage1(selectedTab: $selectedTab)
                .tabItem {
                    Label("Introduction", systemImage: "1.circle")
                }
                .tag(0)

            TutorialTabPage2(selectedTab: $selectedTab)
                .tabItem {
                    Label("Features", systemImage: "2.circle")
                }
                .tag(1)

            TutorialTabPage3(selectedTab: $selectedTab)
                .tabItem {
                    Label("Usage", systemImage: "3.circle")
                }
                .tag(2)

            TutorialTabPage4(selectedTab: $selectedTab)
                .tabItem {
                    Label("Tips", systemImage: "4.circle")
                }
                .tag(3)

            TutorialTabPage5(selectedTab: $selectedTab)
                .tabItem {
                    Label("Summary", systemImage: "5.circle")
                }
                .tag(4)
        }
    }
}

// MARK: - Page 1: Main Screen

private struct TutorialTabPage1: View {
    @Binding var selectedTab: Int
    @State private var isImageEnlarged = false
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationButtonsView(selectedTab: $selectedTab, isLastPage: false)
            
            ImageSection(
                imageName: "NavigationScreen",
                isEnlarged: $isImageEnlarged,
                accessibilityLabel: "Tutorial page 1 image"
            )
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Main Screen (Map View)")
                        .font(.title)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 8)
                    
                    FeatureGroup(title: "Navigation Controls") {
                        FeatureItem(color: "Red", description: "Opens favorite addresses screen for quick access to saved locations")
                        FeatureItem(color: "Cyan", description: "Recenters map view: 1 press = recenter, 2 presses = auto-follow mode")
                        FeatureItem(color: "Dark green", description: "Address input field for navigation destination")
                    }
                    
                    FeatureGroup(title: "Trip Information") {
                        FeatureItem(color: "Light green", description: "Displays traveled distance")
                        FeatureItem(color: "Yellow", description: "Shows estimated arrival time (visible only with active destination)")
                        FeatureItem(color: "Light blue", description: "Start trip or navigation")
                    }
                    
                    FeatureGroup(title: "Main Navigation") {
                        FeatureItem(color: "Dark blue", description: "Map view (current screen)")
                        FeatureItem(color: "Orange", description: "Trip log screen with all recorded trips")
                        FeatureItem(color: "Pink", description: "Mileage report with graphs and statistics")
                        FeatureItem(color: "White", description: "Settings page")
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .fullScreenCover(isPresented: $isImageEnlarged) {
            ImageEnlargedView(imageName: "NavigationScreen", isPresented: $isImageEnlarged)
        }
    }
}

// MARK: - Page 2: Navigation Screen

private struct TutorialTabPage2: View {
    @Binding var selectedTab: Int
    @State private var isImageEnlarged = false
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationButtonsView(selectedTab: $selectedTab, isLastPage: false)
            
            ImageSection(
                imageName: "ActiveNavigation",
                isEnlarged: $isImageEnlarged,
                accessibilityLabel: "Tutorial page 2 image"
            )
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Navigation Screen")
                        .font(.title)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 8)
                    
                    FeatureGroup(title: "Navigation Details") {
                        FeatureItem(color: "Red", description: "View turn-by-turn directions list for current route")
                        FeatureItem(color: "Light green", description: "Shows current navigation destination")
                        FeatureItem(color: "Orange", description: "Trip ETA (visible during active navigation)")
                    }
                    
                    FeatureGroup(title: "Trip Tracking") {
                        FeatureItem(color: "Dark green", description: "Distance traveled since trip start")
                    }
                    
                    FeatureGroup(title: "Controls") {
                        FeatureItem(color: "Cyan", description: "Mute/unmute spoken turn-by-turn directions")
                        FeatureItem(color: "Dark blue", description: "Recenter view on current location")
                        FeatureItem(color: "Light blue", description: "End trip and navigation")
                        FeatureItem(color: "Pink", description: "End navigation only (keeps trip tracking active)")
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .fullScreenCover(isPresented: $isImageEnlarged) {
            ImageEnlargedView(imageName: "ActiveNavigation", isPresented: $isImageEnlarged)
        }
    }
}

// MARK: - Page 3: Trip Log Screen

private struct TutorialTabPage3: View {
    @Binding var selectedTab: Int
    @State private var isImageEnlarged = false
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationButtonsView(selectedTab: $selectedTab, isLastPage: false)
            
            ImageSection(
                imageName: "TripLogScreen",
                isEnlarged: $isImageEnlarged,
                accessibilityLabel: "Tutorial page 3 image"
            )
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Trip Log Screen")
                        .font(.title)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 8)
                    
                    FeatureGroup(title: "Search & Filter") {
                        FeatureItem(color: "White", description: "Search trip logs by notes or category")
                        FeatureItem(color: "Orange", description: "Sort trip logs by various criteria")
                    }
                    
                    FeatureGroup(title: "Bulk Actions") {
                        FeatureItem(color: "Yellow", description: "Select all trip logs at once")
                        FeatureItem(color: "Pink", description: "Export selected trip logs")
                        FeatureItem(color: "Red", description: "Delete selected trip logs")
                    }
                    
                    FeatureGroup(title: "Individual Trip Actions") {
                        FeatureItem(color: "Light blue", description: "Manually select individual trip logs")
                        FeatureItem(color: "Cyan", description: "Open trip log edit screen")
                        FeatureItem(color: "Dark blue", description: "Show/hide route map for the trip")
                        FeatureItem(color: "Dark green", description: "View attached images")
                        FeatureItem(color: "Light green", description: "Listen to recorded audio logs")
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .fullScreenCover(isPresented: $isImageEnlarged) {
            ImageEnlargedView(imageName: "TripLogScreen", isPresented: $isImageEnlarged)
        }
    }
}

// MARK: - Page 4: Trip Log Edit Screen

private struct TutorialTabPage4: View {
    @Binding var selectedTab: Int
    @State private var isImageEnlarged = false
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationButtonsView(selectedTab: $selectedTab, isLastPage: false)
            
            ImageSection(
                imageName: "TripLogEditScreen",
                isEnlarged: $isImageEnlarged,
                accessibilityLabel: "Tutorial page 4 image"
            )
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Trip Log Edit Screen")
                        .font(.title)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 8)
                    
                    FeatureGroup(title: "Save Options") {
                        FeatureItem(color: "Orange", description: "Exit without saving changes")
                        FeatureItem(color: "Yellow", description: "Save all changes to trip log")
                    }
                    
                    FeatureGroup(title: "Trip Details") {
                        FeatureItem(color: "Dark green", description: "Select trip category")
                        FeatureItem(color: "Light green", description: "Add custom notes")
                        FeatureItem(color: "Cyan", description: "Enter trip-related dollar amount")
                    }
                    
                    FeatureGroup(title: "Attachments") {
                        FeatureItem(color: "Dark blue", description: "Add photos to trip log")
                        FeatureItem(color: "Light blue", description: "Record audio logs")
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .fullScreenCover(isPresented: $isImageEnlarged) {
            ImageEnlargedView(imageName: "TripLogEditScreen", isPresented: $isImageEnlarged)
        }
    }
}

// MARK: - Page 5: Mileage Report Screen

private struct TutorialTabPage5: View {
    @Binding var selectedTab: Int
    @State private var isImageEnlarged = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Previous") {
                    if selectedTab > 0 {
                        selectedTab -= 1
                    }
                }
                .disabled(selectedTab == 0)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .fontWeight(.semibold)
            }
            .padding(.top, 24)
            .padding(.horizontal)
            
            ImageSection(
                imageName: "MileageTrackerScreen",
                isEnlarged: $isImageEnlarged,
                accessibilityLabel: "Tutorial page 5 image"
            )
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Mileage Report Screen")
                        .font(.title)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 8)
                    
                    FeatureGroup(title: "Filters & Reports") {
                        FeatureItem(color: "Red", description: "Filter trips by time frame (daily, weekly, monthly, yearly)")
                        FeatureItem(color: "Cyan", description: "Filter trips by category")
                    }
                    
                    Text("View comprehensive mileage and time graphs based on your selected filters.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .fullScreenCover(isPresented: $isImageEnlarged) {
            ImageEnlargedView(imageName: "MileageTrackerScreen", isPresented: $isImageEnlarged)
        }
    }
}

// MARK: - Reusable Components

private struct NavigationButtonsView: View {
    @Binding var selectedTab: Int
    let isLastPage: Bool
    
    var body: some View {
        HStack {
            Button("Previous") {
                if selectedTab > 0 {
                    selectedTab -= 1
                }
            }
            .disabled(selectedTab == 0)

            Spacer()

            Button(isLastPage ? "Done" : "Next") {
                if selectedTab < 4 {
                    selectedTab += 1
                }
            }
            .disabled(selectedTab == 4)
            .fontWeight(isLastPage ? .semibold : .regular)
        }
        .padding(.top, 24)
        .padding(.horizontal)
    }
}

private struct ImageSection: View {
    let imageName: String
    @Binding var isEnlarged: Bool
    let accessibilityLabel: String
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: { isEnlarged = true }) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 380, maxHeight: 380)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .padding(.vertical, 12)
                    .accessibilityLabel(accessibilityLabel)
            }
            .buttonStyle(PlainButtonStyle())
            
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundColor(.accentColor)
                Text("Tap image to enlarge")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 12)
        }
    }
}

private struct FeatureGroup<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(.leading, 8)
        }
    }
}

private struct FeatureItem: View {
    let color: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.accentColor.opacity(0.8))
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(color)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ImageEnlargedView: View {
    let imageName: String
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                
                Spacer()
                
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .padding()
                
                Spacer()
                
                Button("Close") {
                    isPresented = false
                }
                .font(.title3)
                .fontWeight(.medium)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.9))
                .foregroundColor(.black)
                .cornerRadius(10)
                .padding(.bottom, 32)
            }
        }
    }
}
