import SwiftUI

struct OnboardingView: View {
    var onDismiss: () -> Void
    
    @State private var currentPage = 0
    @State private var firstName: String = ""
    let totalPages = 4
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            VStack {
                Spacer(minLength: 30)
                TabView(selection: $currentPage) {
                    WelcomePage().tag(0)
                    FirstNamePage(firstName: $firstName).tag(1)
                    FeaturesPage().tag(2)
                    ReadyPage(firstName: firstName).tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                Spacer()

                PageControl(currentPage: currentPage, totalPages: totalPages)
                    .padding(.bottom, 16)
                
                if currentPage == totalPages - 1 {
                    Button(action: {
                        UserDefaults.standard.set(firstName.trimmingCharacters(in: .whitespaces), forKey: "userFirstName")
                        onDismiss()
                    }) {
                        Text("Get Started")
                            .bold()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .transition(.opacity)
                } else {
                    Button(action: {
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
                    .padding(.horizontal)
                    .transition(.opacity)
                    .disabled(currentPage == 1 && firstName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()
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
            Text("Welcome to Photo Tracker w/ Map")
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

struct FeaturesPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("PTWM helps you track your trips with ease:")
                .font(.headline)
                .padding(.bottom, 8)
            BulletPoint(text: "Track route, distance, and time of your trips.")
            BulletPoint(text: "Add notes, pay, and photos to each trip.")
            BulletPoint(text: "Attach audio notes with built-in recording.")
            BulletPoint(text: "See your route on a live map.")
            BulletPoint(text: "Save trip details for future reference.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.top, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ReadyPage: View {
    var firstName: String
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Image(systemName: "map")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .foregroundColor(.accentColor)
            Text("You're ready to start tracking your trips, \(firstName.isEmpty ? "friend" : firstName)!")
                .font(.title2)
                .fontWeight(.medium)
            Spacer()
        }
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
    OnboardingView { }
}
