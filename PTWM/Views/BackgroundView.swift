import SwiftUI

struct BackgroundView: View {
    @EnvironmentObject var tripManager: TripManager
    @Environment(\.dismiss) var dismiss
    @State private var showingImagePicker = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let bgImage = tripManager.backgroundImage {
                    Image(uiImage: bgImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(10)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                        .overlay(
                            Text("No Background Image")
                                .foregroundColor(.gray)
                        )
                        .cornerRadius(10)
                }
                
                Button("Change Background Image") {
                    showingImagePicker = true
                }
                .buttonStyle(.borderedProminent)
                
                if tripManager.backgroundImage != nil {
                    Button("Remove Background Image") {
                        tripManager.removeBackgroundImage()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Background")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {  // Changed from $showImagePicker
                ImagePicker.photoLibrary { result in
                    switch result {
                    case .success(let image):
                        tripManager.backgroundImage = image
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
            .alert("Image Selection Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
}
