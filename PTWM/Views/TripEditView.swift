//
//  TripEditView.swift
//  waylon
//
//  Created by tyler kaska on 6/26/25.
//

import SwiftUI
import AVFoundation

struct TripEditView: View {
    @Environment(\.dismiss) var dismiss
    @State var trip: Trip
    var onSave: (Trip) -> Void

    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker = false
    @State private var audioNotes: [URL] = []
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder? = nil
    
    @State private var selectedFullImage: UIImage? = nil
    
    @State private var selectedReason: String = ""
    @State private var customReason: String = ""

    @AppStorage("tripCategories") private var tripCategoriesData: String = ""
    
    private var supportedCategories: [String] {
        let defaultCategories = ["Business", "Personal", "Vacation", "Photography", "DoorDash", "Uber"]
        if let data = tripCategoriesData.data(using: .utf8),
           let categories = try? JSONDecoder().decode([String].self, from: data),
           !categories.isEmpty {
            var filtered = categories.filter { $0 != "Other" }
            filtered.append("Other")
            return filtered
        } else {
            return defaultCategories + ["Other"]
        }
    }

    init(trip: Trip, onSave: @escaping (Trip) -> Void) {
        _trip = State(initialValue: trip)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Trip Reason")) {
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(supportedCategories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    if selectedReason == "Other" {
                        TextField("Enter custom reason", text: $customReason)
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextField("Notes", text: $trip.notes)
                }
                
                Section(header: Text("Pay")) {
                    TextField("Pay", text: $trip.pay)
                }
                
                Section(header: Text("Photos")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(selectedImages, id: \.self) { img in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .frame(width: 70, height: 70)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    Button {
                                        selectedImages.removeAll { $0 == img }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .background(Color.white)
                                            .clipShape(Circle())
                                            .padding(6)
                                    }
                                    .offset(x: 12, y: -12)
                                    .zIndex(1)
                                    .contentShape(Rectangle())
                                }
                            }
                            Button {
                                showImagePicker = true
                            } label: {
                                Image(systemName: "plus.circle.fill").font(.largeTitle)
                            }
                        }
                    }
                }
                
                Section(header: Text("Audio Notes")) {
                    Button(isRecording ? "Stop Recording" : "Record Audio") {
                        if isRecording {
                            audioRecorder?.stop()
                            if let url = audioRecorder?.url {
                                audioNotes.append(url)
                            }
                            isRecording = false
                        } else {
                            let docDir = FileManager.default.temporaryDirectory
                            let url = docDir.appendingPathComponent(UUID().uuidString + ".m4a")
                            let settings = [
                                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                                AVSampleRateKey: 12000,
                                AVNumberOfChannelsKey: 1,
                                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                            ]
                            audioRecorder = try? AVAudioRecorder(url: url, settings: settings)
                            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                                if granted {
                                    DispatchQueue.main.async {
                                        audioRecorder?.record()
                                        isRecording = true
                                    }
                                }
                            }
                        }
                    }
                    ForEach(audioNotes, id: \.self) { url in
                        HStack {
                            Text(url.lastPathComponent)
                                .font(.caption)
                            Spacer()
                            Button {
                                audioNotes.removeAll { $0 == url }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
            }
            .navigationTitle("Edit Trip")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if selectedReason == "Other" {
                            trip.reason = customReason
                        } else {
                            trip.reason = selectedReason
                        }
                        trip.photoURLs = selectedImages.compactMap { image in
                            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                            if let data = image.jpegData(compressionQuality: 0.8) {
                                try? data.write(to: url)
                                return url
                            }
                            return nil
                        }
                        trip.audioNotes = audioNotes
                        onSave(trip)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker { img in
                    selectedImages.append(img)
                }
            }
            .onAppear {
                selectedImages = trip.photoURLs.compactMap { url in
                    if let data = try? Data(contentsOf: url), let img = UIImage(data: data) { return img }
                    return nil
                }
                audioNotes = trip.audioNotes

                if supportedCategories.contains(trip.reason) {
                    selectedReason = trip.reason
                    customReason = ""
                } else if trip.reason.isEmpty {
                    selectedReason = supportedCategories.first ?? "Business"
                    customReason = ""
                } else {
                    selectedReason = "Other"
                    customReason = trip.reason
                }
            }
        }
        .sheet(item: $selectedFullImage) { image in
            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    Spacer()
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                    Spacer()
                    Button("Close") {
                        selectedFullImage = nil
                    }
                    .padding()
                    .background(Color.white.opacity(0.7))
                    .cornerRadius(10)
                }
            }
        }
    }
}

extension UIImage: Identifiable {
    public var id: String { self.pngData()?.base64EncodedString() ?? UUID().uuidString }
}
