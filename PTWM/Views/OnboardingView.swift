// This view now relies on its parent to present TutorialScreenPage as a navigation destination when showTutorial becomes true.
import SwiftUI
import UIKit

struct OnboardingView: View {
    var onDismiss: () -> Void
    @Binding var showTutorial: Bool
    
    @State private var currentPage = 0
    @State private var firstName: String = ""
    @State private var didRequestTutorial = false
    @AppStorage("userFirstName") private var userFirstName: String = ""
    let totalPages = 3
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            VStack {
                Spacer(minLength: 30)
                TabView(selection: $currentPage) {
                    WelcomePage().tag(0)
                    FirstNamePage(firstName: $firstName).tag(1)
                    TutorialPromptPage(onYes: {
                        didRequestTutorial = true
                        onDismiss()
                    }, onNo: { onDismiss() }).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                Spacer()

                PageControl(currentPage: currentPage, totalPages: totalPages)
                    .padding(.bottom, 16)
                
                if currentPage != 2 {
                    Button(action: {
                        if currentPage == 1 {
                            userFirstName = firstName
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        withAnimation { currentPage += 1 }
                    }) {
                        Text("Next")
                            .bold()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.accentColor.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(currentPage == 1 && firstName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal)
                    .transition(.opacity)
                }
            }
            .padding()
        }
        .onDisappear {
            if didRequestTutorial {
                showTutorial = true
            }
        }
    }
}

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 32) {
            Image("waylonLogo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 120, maxHeight: 120)
                .padding(.bottom, 12)
                .accessibilityLabel("Waylon Logo")
            Text("Welcome to SafelyRouted (formerly Photo Tracker w/ Map)")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Easily track and relive your trips.")
                .font(.title3)
        }
        .padding(.top, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FirstNamePage: View {
    @Binding var firstName: String
    var body: some View {
        VStack(spacing: 28) {
            Text("What's your first name?")
                .font(.title2)
                .bold()
            TextField("First name", text: $firstName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .autocapitalization(.words)
                .disableAutocorrection(true)
        }
        .padding(.top, 64)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TutorialPromptPage: View {
    let onYes: () -> Void
    let onNo: () -> Void
    var body: some View {
        VStack(spacing: 32) {
            Text("Need a tutorial?")
                .font(.title2)
                .bold()
            HStack(spacing: 20) {
                Button(action: onYes) {
                    Text("Yes!")
                        .bold()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                Button(action: onNo) {
                    Text("No.")
                        .bold()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.4))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BulletPoint: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").bold()
            Text(text)
        }
    }
}

struct PageControl: View {
    let currentPage: Int
    let totalPages: Int
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)
            }
        }
    }
}

#Preview {
    // Note: Updated to pass a .constant(false) binding for showTutorial in preview
    OnboardingView(onDismiss: {}, showTutorial: .constant(false))
}
