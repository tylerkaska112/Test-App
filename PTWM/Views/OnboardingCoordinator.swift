import SwiftUI

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
