// Enhanced OnboardingView with improved UX, accessibility, and validation
import SwiftUI
import UIKit

struct OnboardingView: View {
    var onDismiss: () -> Void
    @Binding var showTutorial: Bool
    
    @State private var currentPage = 0
    @State private var firstName: String = ""
    @State private var didRequestTutorial = false
    @State private var showingSkipAlert = false
    @AppStorage("userFirstName") private var userFirstName: String = ""
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    
    let totalPages = 3
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack {
                // Skip button for faster navigation
                HStack {
                    Spacer()
                    if currentPage < 2 {
                        Button(action: {
                            showingSkipAlert = true
                        }) {
                            Text("Skip")
                                .foregroundColor(.secondary)
                                .padding(.trailing)
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.top, 8)
                
                Spacer(minLength: 30)
                
                TabView(selection: $currentPage) {
                    WelcomePage().tag(0)
                    FirstNamePage(firstName: $firstName).tag(1)
                    TutorialPromptPage(onYes: {
                        didRequestTutorial = true
                        hasCompletedOnboarding = true
                        onDismiss()
                    }, onNo: {
                        hasCompletedOnboarding = true
                        onDismiss()
                    }).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                Spacer()

                PageControl(currentPage: currentPage, totalPages: totalPages)
                    .padding(.bottom, 16)
                
                if currentPage != 2 {
                    Button(action: {
                        handleNextButton()
                    }) {
                        Text(currentPage == 1 ? "Continue" : "Next")
                            .bold()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isNextButtonEnabled ? Color.accentColor : Color.gray.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!isNextButtonEnabled)
                    .padding(.horizontal)
                    .transition(.opacity)
                }
            }
            .padding()
        }
        .alert("Skip Onboarding?", isPresented: $showingSkipAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Skip", role: .destructive) {
                hasCompletedOnboarding = true
                onDismiss()
            }
        } message: {
            Text("You can always access the tutorial later from settings.")
        }
        .onDisappear {
            if didRequestTutorial {
                showTutorial = true
            }
        }
    }
    
    private var isNextButtonEnabled: Bool {
        if currentPage == 1 {
            return !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }
    
    private func handleNextButton() {
        if currentPage == 1 {
            let trimmedName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            userFirstName = trimmedName
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        withAnimation {
            currentPage += 1
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
            
            Text("Welcome to SafelyRouted")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Formerly Photo Tracker w/ Map")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Easily track and relive your trips")
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            
            // Feature highlights
            VStack(alignment: .leading, spacing: 16) {
                FeatureBullet(icon: "map.fill", text: "Track your journeys in real-time")
                FeatureBullet(icon: "photo.fill", text: "Attach photos to locations")
                FeatureBullet(icon: "clock.fill", text: "Review your travel history")
            }
            .padding(.top, 24)
            .padding(.horizontal)
        }
        .padding(.top, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeatureBullet: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text(text)
                .font(.body)
        }
    }
}

struct FirstNamePage: View {
    @Binding var firstName: String
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 28) {
            Text("What's your first name?")
                .font(.title2)
                .bold()
                .multilineTextAlignment(.center)
            
            Text("We'll use this to personalize your experience")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            TextField("First name", text: $firstName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 32)
                .autocapitalization(.words)
                .disableAutocorrection(true)
                .submitLabel(.continue)
                .focused($isTextFieldFocused)
                .accessibilityLabel("First name input field")
                .accessibilityHint("Enter your first name to personalize the app")
        }
        .padding(.top, 64)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Auto-focus the text field when this page appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
}

struct TutorialPromptPage: View {
    let onYes: () -> Void
    let onNo: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
                .padding(.bottom, 8)
            
            Text("Want a quick tour?")
                .font(.title2)
                .bold()
                .multilineTextAlignment(.center)
            
            Text("Learn how to make the most of SafelyRouted in just a minute")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                Button(action: onYes) {
                    VStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                        Text("Show me")
                            .bold()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .accessibilityLabel("Start tutorial")
                
                Button(action: onNo) {
                    VStack(spacing: 8) {
                        Image(systemName: "forward.fill")
                            .font(.title)
                        Text("Skip")
                            .bold()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
                .accessibilityLabel("Skip tutorial")
            }
            .padding(.horizontal)
        }
        .padding(.top, 60)
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
                    .animation(.easeInOut, value: currentPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(currentPage + 1) of \(totalPages)")
    }
}

#Preview {
    OnboardingView(onDismiss: {}, showTutorial: .constant(false))
}
