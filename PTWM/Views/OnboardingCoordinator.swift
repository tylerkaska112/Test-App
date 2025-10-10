import SwiftUI

/// This view coordinates showing onboarding and then showing the tutorial as a new page, not a modal sheet.
struct OnboardingCoordinator: View {
    @State private var showOnboarding = true
    @State private var showTutorial = false
    
    var body: some View {
        NavigationStack {
            Group {
                if showOnboarding {
                    OnboardingView(onDismiss: { showOnboarding = false }, showTutorial: $showTutorial)
                } else if showTutorial {
                    TutorialScreenPage()
                } else {
                    // Replace with your main app content
                    Text("Main App Content Here")
                }
            }
            .navigationDestination(isPresented: $showTutorial) {
                TutorialScreenPage()
            }
        }
    }
}

#Preview {
    OnboardingCoordinator()
}
