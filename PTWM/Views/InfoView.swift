import SwiftUI

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Image("AppIcon")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding()
                
                Text("SafelyRouted helps you navigate your travels with real-time safety alerts, route planning, and community-driven updates. Stay informed and make smarter, safer travel decisions, wherever you go.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Features")
                        .font(.headline)
                        .padding(.top, 8)
                    Group {
                        Text("• Real-time navigation")
                        Text("• Customizable safe route planning")
                        Text("• Community updates and feedback")
                        Text("• Offline access to saved routes")
                        Text("• Privacy-focused, no tracking")
                    }
                    .font(.subheadline)
                    .padding(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("Version: 2.4")
                    .padding()

                Spacer()
                
                Text("© Tyler Kaska, SafelyRouted, 2025")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 18)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct InfoView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            InfoView()
        }
    }
}
