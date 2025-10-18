import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    var enableZoom: Bool = false
    var completion: (Result<UIImage, Error>) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = false
        
        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            picker.mediaTypes = ["public.image"]
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                if self.parent.enableZoom {
                    let zoomView = ImageZoomView(image: image) { [weak self] croppedImage in
                        guard let self = self else { return }
                        if let cropped = croppedImage {
                            self.parent.completion(.success(cropped))
                        } else {
                            self.parent.completion(.success(image))
                        }
                        picker.dismiss(animated: true)
                    }
                    let hostingController = UIHostingController(rootView: zoomView)
                    picker.present(hostingController, animated: true)
                } else {
                    self.parent.completion(.success(image))
                    picker.dismiss(animated: true)
                }
            } else {
                self.parent.completion(.failure(ImagePickerError.noImageSelected))
                picker.dismiss(animated: true)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            self.parent.completion(.failure(ImagePickerError.cancelled))
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Image Zoom View
struct ImageZoomView: View {
    let image: UIImage
    let completion: (UIImage?) -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @GestureState private var magnificationState: CGFloat = 1.0
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale * magnificationState)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .updating($magnificationState) { value, state, _ in
                                    state = value
                                }
                                .onEnded { value in
                                    scale *= value
                                    scale = min(max(scale, 1.0), 10.0)
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    lastScale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.0
                                    lastScale = 2.0
                                }
                            }
                        }
                }
            }
            .navigationTitle("Zoom & Crop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        completion(nil)
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        let croppedImage = cropImage()
                        completion(croppedImage)
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button {
                            withAnimation(.spring()) {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            }
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Text("Pinch to zoom • Double tap • Drag to pan")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
        }
    }
    
    private func cropImage() -> UIImage? {
        guard scale > 1.0 else {
            return image
        }
        
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { context in
            image.draw(at: .zero)
        }
    }
}

// MARK: - Error Types
enum ImagePickerError: LocalizedError {
    case noImageSelected
    case cancelled
    case sourceTypeNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .noImageSelected:
            return "No image was selected"
        case .cancelled:
            return "Image selection was cancelled"
        case .sourceTypeNotAvailable:
            return "The requested source type is not available"
        }
    }
}

// MARK: - Convenience Extensions
extension ImagePicker {
    static func photoLibrary(enableZoom: Bool = false, completion: @escaping (Result<UIImage, Error>) -> Void) -> ImagePicker {
        ImagePicker(sourceType: .photoLibrary, enableZoom: enableZoom, completion: completion)
    }
    
    static func camera(enableZoom: Bool = false, completion: @escaping (Result<UIImage, Error>) -> Void) -> ImagePicker {
        ImagePicker(sourceType: .camera, enableZoom: enableZoom, completion: completion)
    }
    
    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}

// MARK: - Example Usage
struct ContentView_Preview: View {
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
            }
            
            Button("Select & Zoom Image") {
                showImagePicker = true
            }
        }
        .padding()
        .sheet(isPresented: $showImagePicker) {
            ImagePicker.photoLibrary(enableZoom: true) { result in
                switch result {
                case .success(let image):
                    selectedImage = image
                case .failure(let error):
                    print("Error: \(error)")
                }
            }
        }
    }
}
