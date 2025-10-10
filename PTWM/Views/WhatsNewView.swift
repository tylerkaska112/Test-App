import SwiftUI

struct WhatsNewView: View {
    let currentVersion: String
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("What's Changed in this Version")) {
                    // TODO: Fill in changes for this release
                    Text("• Multiple **UI** updates were made making the app look and feel better overall.")
                    Text("• Added **better** achievements that allow more fun to be had!")
                    Text("• Added the ability to import past trips from a **CSV/JSON File**.")
                    Text("• Added a **show unlocked** button to the achievements screen that allows users to view all their unlocked achievements.")
                    Text("• Added a search bar to both the **settings** page and **achievements** page.")
                    Text("• Added a new **export** button to the mileage report screen to allow users to export all their trip data for easy viewing. (Available in **CSV** and **JSON**)")
                    Text("• Added a **trip summary** section to the trip log screen that shows the amount of trips available and total distance traveled as well as average distance, duration, spped, and category.")
                    Text("• Added an extra button that allows users to confirm they want to end a trip.")
                    Text("• Fixed some simple logic that makes the app process trips **better** and overall run **smoother**.")
                }
                Section(header: Text("Currently Working On")) {
                    // TODO: Fill in upcoming/ongoing features
                    Text("• I have a whole extensive list of features that id like to add to this app but unfortunately Apple went ahead and suspended my developer account so I can't feasibly add any features like Carplay.")
                }
            }
            .navigationTitle("What’s New (v\(currentVersion))")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    WhatsNewView(currentVersion: "2.4.0", onDismiss: {})
}
#endif
