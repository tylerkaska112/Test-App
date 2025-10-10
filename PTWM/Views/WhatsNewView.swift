import SwiftUI

struct WhatsNewView: View {
    let currentVersion: String
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("What's Changed in this Version")) {
                    // TODO: Fill in changes for this release
                    Text("• **Achievements** are here! You can now collect badges by traveling a certain distance or time.")
                    Text("• The **What's New** screen is now available and will be shown with every new update to the app!")
                    Text("• Added a new super secret code to open a **special** screen in the app! (hint: It has something to do with the code input screen in the settings)")
                    Text("• Bug fixes and performance improvements.")
                }
                Section(header: Text("Currently Working On")) {
                    // TODO: Fill in upcoming/ongoing features
                    Text("• **Live Activies support**.")
                    Text("• **Widget integration**.")
                    Text("• **Implementing Carplay**. Currently waiting for apple to approve my application for the CarPlay navigation entitlement.")
                    Text("• Custom **Background** and **Theme** support.")
                    Text("• **Location based image tagging**. (Images shown on your traveled route)")
                    Text("• More tracking features including **fitness tracking**, **step tracking**, and more **fitness related features**.")
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
