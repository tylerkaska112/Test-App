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

private struct TutorialTabPage1: View {
    @Binding var selectedTab: Int
    @State private var isImageEnlarged = false
    
    var body: some View {
        VStack {
            HStack {
                Button("Previous") {
                    if selectedTab > 0 {
                        selectedTab -= 1
                    }
                }
                .disabled(selectedTab == 0)

                Spacer()

                Button("Next") {
                    if selectedTab < 4 {
                        selectedTab += 1
                    }
                }
                .disabled(selectedTab == 4)
            }
            .padding(.top, 24)
            .padding(.horizontal)
            
            Button(action: { isImageEnlarged = true }) {
                Image("NavigationScreen")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 380, maxHeight: 380)
                    .padding(.vertical, 12)
                    .accessibilityLabel("Tutorial page 1 image")
            }
            .buttonStyle(PlainButtonStyle())
            
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundColor(.accentColor)
                Text("Click image to enlarge")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 4)
            
            ScrollView {
                VStack(spacing: 24) {
                    Text("Main Screen (Map view)")
                        .font(.title)
                        .bold()
                    Text("""
- Red, opens favorite addresses screen to allow users to pick a saved address for easy navigation
- Cyan, recenters the map view onto the users current location, 1 press recenters but doesn’t enable following, 2 presses enables automatic location following making the view always have the users location in the center of the screen
- Dark green, text box where the user can type in any address for navigation
- Light green, shows the users traveled distance
- Yellow, show the arrival eta to the users inputted address, will not be visible if there is no address typed in
- Light blue, starts a trip or navigation
- Dark blue, take the user to the main screen with the map
- Orange, takes the user to the trip log screen with all the trip logs
- Pink, takes the user to the mileage report screen with the mileage and time graphs
- White, takes the user to the settings page
""")
                    .font(.body)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fullScreenCover(isPresented: $isImageEnlarged) {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    Spacer()
                    Image("NavigationScreen")
                        .resizable()
                        .scaledToFit()
                        .padding()
                    Spacer()
                    Button("Close") { isImageEnlarged = false }
                        .font(.title3)
                        .padding()
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(10)
                }
            }
        }
    }
}

private struct TutorialTabPage2: View {
    @Binding var selectedTab: Int
    @State private var isImageEnlarged2 = false
    
    var body: some View {
        VStack {
            HStack {
                Button("Previous") {
                    if selectedTab > 0 {
                        selectedTab -= 1
                    }
                }
                .disabled(selectedTab == 0)

                Spacer()

                Button("Next") {
                    if selectedTab < 4 {
                        selectedTab += 1
                    }
                }
                .disabled(selectedTab == 4)
            }
            .padding(.top, 24)
            .padding(.horizontal)
            
            Button(action: { isImageEnlarged2 = true }) {
                Image("ActiveNavigation")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 380, maxHeight: 380)
                    .padding(.vertical, 12)
                    .accessibilityLabel("Tutorial page 2 image")
            }
            .buttonStyle(PlainButtonStyle())
            
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundColor(.accentColor)
                Text("Click image to enlarge")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 4)
            
            ScrollView {
                VStack(spacing: 24) {
                    Text("Navigation Screen")
                        .font(.title)
                        .bold()
                    Text("""
- Red, click this to open the list of directions for the current navigation route
- Dark green, shows how far the user has traveled since starting the trip
- Orange, shows the trip eta inside navigation, will not show when outside navigation
- Cyan, spoken turn by turn navigation mute button
- Dark blue, recenters the users view on their current location (doesn’t work rn)
- Light green, shows the address where the user is currently navigating to (won’t be there when not navigating)
- Light blue, ends the trip and navigation
- Pink, only ends navigation while keeping trip tracking active
""")
                    .font(.body)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fullScreenCover(isPresented: $isImageEnlarged2) {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    Spacer()
                    Image("ActiveNavigation")
                        .resizable()
                        .scaledToFit()
                        .padding()
                    Spacer()
                    Button("Close") { isImageEnlarged2 = false }
                        .font(.title3)
                        .padding()
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(10)
                }
            }
        }
    }
}

private struct TutorialTabPage3: View {
    @Binding var selectedTab: Int
    @State private var isImageEnlarged3 = false
    
    var body: some View {
        VStack {
            HStack {
                Button("Previous") {
                    if selectedTab > 0 {
                        selectedTab -= 1
                    }
                }
                .disabled(selectedTab == 0)

                Spacer()

                Button("Next") {
                    if selectedTab < 4 {
                        selectedTab += 1
                    }
                }
                .disabled(selectedTab == 4)
            }
            .padding(.top, 24)
            .padding(.horizontal)
            
            Button(action: { isImageEnlarged3 = true }) {
                Image("TripLogScreen")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 380, maxHeight: 380)
                    .padding(.vertical, 12)
                    .accessibilityLabel("Tutorial page 3 image")
            }
            .buttonStyle(PlainButtonStyle())
            
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundColor(.accentColor)
                Text("Click image to enlarge")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 4)
            
            ScrollView {
                VStack(spacing: 24) {
                    Text("Trip Log Screen")
                        .font(.title)
                        .bold()
                    Text("""
- White, search bar allowing users to search trip logs via notes or category
- Pink, allows the user to export trip logs when trip logs are selected
- Red, allows users to delete trip logs when trip logs are selected
- Yellow, allows users to select all trip logs at one time for easy exporting or deletion
- Orange, allows users to sort trip logs by multiple categories
- Dark green, allows users to open user added images
- Light green, allows user to listen to user recorded audio logs
- Light blue, select trip log manually
- Dark blue, hides or shows the map showing the user the route driven
- Cyan, allows users to open a trip log edit screen
""")
                    .font(.body)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fullScreenCover(isPresented: $isImageEnlarged3) {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    Spacer()
                    Image("TripLogScreen")
                        .resizable()
                        .scaledToFit()
                        .padding()
                    Spacer()
                    Button("Close") { isImageEnlarged3 = false }
                        .font(.title3)
                        .padding()
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(10)
                }
            }
        }
    }
}

private struct TutorialTabPage4: View {
    @Binding var selectedTab: Int
    @State private var isImageEnlarged4 = false
    
    var body: some View {
        VStack {
            HStack {
                Button("Previous") {
                    if selectedTab > 0 {
                        selectedTab -= 1
                    }
                }
                .disabled(selectedTab == 0)

                Spacer()

                Button("Next") {
                    if selectedTab < 4 {
                        selectedTab += 1
                    }
                }
                .disabled(selectedTab == 4)
            }
            .padding(.top, 24)
            .padding(.horizontal)
            
            Button(action: { isImageEnlarged4 = true }) {
                Image("TripLogEditScreen")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 380, maxHeight: 380)
                    .padding(.vertical, 12)
                    .accessibilityLabel("Tutorial page 4 image")
            }
            .buttonStyle(PlainButtonStyle())
            
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundColor(.accentColor)
                Text("Click image to enlarge")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 4)
            
            ScrollView {
                VStack(spacing: 24) {
                    Text("Trip Log Edit Screen")
                        .font(.title)
                        .bold()
                    Text("""
- Orange, allows the user to exit the screen WITHOUT saving the inputted information
- Yellow, allows the user to save all changes made to the trip log
- Dark green, allows user to select a category for the trip
- Light green, allows user to add custom notes to the trip log
- Cyan, allows user to input a dollar amount that is related to that certain trip
- Dark blue, allows user to add pictures to the trip log
- Light blue, allows user to record audio logs for that trip
""")
                    .font(.body)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fullScreenCover(isPresented: $isImageEnlarged4) {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    Spacer()
                    Image("TripLogEditScreen")
                        .resizable()
                        .scaledToFit()
                        .padding()
                    Spacer()
                    Button("Close") { isImageEnlarged4 = false }
                        .font(.title3)
                        .padding()
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(10)
                }
            }
        }
    }
}

private struct TutorialTabPage5: View {
    @Binding var selectedTab: Int
    @State private var isImageEnlarged5 = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
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
            }
            .padding(.top, 24)
            .padding(.horizontal)
            
            Button(action: { isImageEnlarged5 = true }) {
                Image("MileageTrackerScreen")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 380, maxHeight: 380)
                    .padding(.vertical, 12)
                    .accessibilityLabel("Tutorial page 5 image")
            }
            .buttonStyle(PlainButtonStyle())
            
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundColor(.accentColor)
                Text("Click image to enlarge")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 4)
            
            ScrollView {
                VStack(spacing: 24) {
                    Text("Mileage Report Screen")
                        .font(.title)
                        .bold()
                    Text("""
- Red, allows the user to filter what trips get shown in the selected time frame
- Cyan, allows user to filter what logs get shown based on the category of trip
""")
                    .font(.body)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fullScreenCover(isPresented: $isImageEnlarged5) {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    Spacer()
                    Image("MileageTrackerScreen")
                        .resizable()
                        .scaledToFit()
                        .padding()
                    Spacer()
                    Button("Close") { isImageEnlarged5 = false }
                        .font(.title3)
                        .padding()
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(10)
                }
            }
        }
    }
}
