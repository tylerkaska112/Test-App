//
//  ImagePicker.swift
//  waylon
//
//  Created by tyler kaska on 6/26/25.
//

import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    var completion: (Result<UIImage, Error>) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = false
        
        // Only set media types if camera is available for the source type
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
            // Try edited image first, fall back to original
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.completion(.success(image))
            } else {
                parent.completion(.failure(ImagePickerError.noImageSelected))
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.completion(.failure(ImagePickerError.cancelled))
            picker.dismiss(animated: true)
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
    /// Creates an ImagePicker for the photo library
    static func photoLibrary(completion: @escaping (Result<UIImage, Error>) -> Void) -> ImagePicker {
        ImagePicker(sourceType: .photoLibrary, completion: completion)
    }
    
    /// Creates an ImagePicker for the camera (if available)
    static func camera(completion: @escaping (Result<UIImage, Error>) -> Void) -> ImagePicker {
        ImagePicker(sourceType: .camera, completion: completion)
    }
    
    /// Checks if camera is available on this device
    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}
