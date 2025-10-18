import SwiftUI
import AVFoundation
import PhotosUI

struct TripEditView: View {
    @Environment(\.dismiss) var dismiss
    @State var trip: Trip
    var onSave: (Trip) -> Void

    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var audioNotes: [URL] = []
    @State private var isRecording = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer? = nil
    @State private var audioRecorder: AVAudioRecorder? = nil
    @State private var audioPlayer: AVAudioPlayer? = nil
    @State private var playingAudioURL: URL? = nil
    
    @State private var selectedFullImage: UIImage? = nil
    @State private var showDeletePhotoAlert = false
    @State private var photoToDelete: UIImage? = nil
    @State private var showDeleteAudioAlert = false
    @State private var audioToDelete: URL? = nil
    @State private var showPhotoSourcePicker = false
    @State private var showPhotoPicker = false
    
    @State private var selectedReason: String = ""
    @State private var customReason: String = ""
    @State private var isSaving = false
    @State private var showValidationError = false
    @State private var validationMessage = ""

    @AppStorage("tripCategories") private var tripCategoriesData: String = ""
    
    private let maxNotesLength = 500
    private let maxPayLength = 50
    private let maxCustomReasonLength = 100
    
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
    
    private var isFormValid: Bool {
        if selectedReason == "Other" {
            return !customReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return !selectedReason.isEmpty
    }

    init(trip: Trip, onSave: @escaping (Trip) -> Void) {
        _trip = State(initialValue: trip)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                tripReasonSection
                notesSection
                paySection
                photosSection
                audioNotesSection
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .overlay {
                savingOverlay
            }
            .sheet(isPresented: $showImagePicker) {
                TripImagePicker(sourceType: imagePickerSourceType) { img in
                    selectedImages.append(img)
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItems, matching: .images)
            .onChange(of: photoPickerItems) { oldValue, newValue in
                loadPhotos(from: newValue)
            }
            .confirmationDialog("Add Photo", isPresented: $showPhotoSourcePicker, titleVisibility: .visible) {
                photoSourceDialogContent
            }
            .sheet(item: $selectedFullImage) { image in
                FullImageView(image: image) {
                    selectedFullImage = nil
                }
            }
            .alert("Delete Photo?", isPresented: $showDeletePhotoAlert) {
                Button("Delete", role: .destructive) {
                    if let img = photoToDelete {
                        selectedImages.removeAll { $0 == img }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This photo will be removed from the trip.")
            }
            .alert("Delete Audio Note?", isPresented: $showDeleteAudioAlert) {
                Button("Delete", role: .destructive) {
                    if let url = audioToDelete {
                        stopAudioPlayback()
                        audioNotes.removeAll { $0 == url }
                        cleanupAudioFile(url: url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This audio note will be permanently deleted.")
            }
            .alert("Validation Error", isPresented: $showValidationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
            .onAppear {
                setupView()
            }
            .onDisappear {
                cleanup()
            }
        }
    }
    
    // MARK: - View Components
    
    private var tripReasonSection: some View {
        Section(header: Text("Trip Reason")) {
            Picker("Reason", selection: $selectedReason) {
                ForEach(supportedCategories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Trip reason picker")
            
            if selectedReason == "Other" {
                customReasonField
            }
        }
    }
    
    private var customReasonField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Enter custom reason", text: $customReason)
                .onChange(of: customReason) { oldValue, newValue in
                    if newValue.count > maxCustomReasonLength {
                        customReason = String(newValue.prefix(maxCustomReasonLength))
                    }
                }
                .accessibilityLabel("Custom trip reason")
            
            Text("\(customReason.count)/\(maxCustomReasonLength)")
                .font(.caption)
                .foregroundColor(customReason.count >= maxCustomReasonLength ? .red : .secondary)
        }
    }
    
    private var notesSection: some View {
        Section(header: Text("Notes")) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Add trip notes", text: $trip.notes, axis: .vertical)
                    .lineLimit(3...6)
                    .onChange(of: trip.notes) { oldValue, newValue in
                        if newValue.count > maxNotesLength {
                            trip.notes = String(newValue.prefix(maxNotesLength))
                        }
                    }
                    .accessibilityLabel("Trip notes")
                
                Text("\(trip.notes.count)/\(maxNotesLength)")
                    .font(.caption)
                    .foregroundColor(trip.notes.count >= maxNotesLength ? .red : .secondary)
            }
        }
    }
    
    private var paySection: some View {
        Section(header: Text("Pay")) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Enter amount", text: $trip.pay)
                    .keyboardType(.decimalPad)
                    .onChange(of: trip.pay) { oldValue, newValue in
                        if newValue.count > maxPayLength {
                            trip.pay = String(newValue.prefix(maxPayLength))
                        }
                    }
                    .accessibilityLabel("Payment amount")
                
                if !trip.pay.isEmpty {
                    Text("\(trip.pay.count)/\(maxPayLength)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var photosSection: some View {
        Section(header: photosSectionHeader) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if !selectedImages.isEmpty {
                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, img in
                            photoThumbnail(image: img, index: index)
                        }
                    }
                    
                    addPhotoButton
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var photosSectionHeader: some View {
        HStack {
            Text("Photos")
            Spacer()
            if !selectedImages.isEmpty {
                Text("\(selectedImages.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func photoThumbnail(image: UIImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture {
                    selectedFullImage = image
                }
                .accessibilityLabel("Photo \(index + 1)")
                .accessibilityHint("Tap to view full size")
            
            Button {
                photoToDelete = image
                showDeletePhotoAlert = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .background(Color.red)
                    .clipShape(Circle())
            }
            .offset(x: 8, y: -8)
            .accessibilityLabel("Delete photo")
        }
    }
    
    private var addPhotoButton: some View {
        Button {
            showPhotoSourcePicker = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)
                Text("Add Photo")
                    .font(.caption)
            }
            .frame(width: 80, height: 80)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityLabel("Add photo")
    }
    
    private var audioNotesSection: some View {
        Section(header: audioNotesSectionHeader) {
            recordButton
            
            if audioNotes.isEmpty && !isRecording {
                emptyAudioState
            }
            
            ForEach(Array(audioNotes.enumerated()), id: \.offset) { index, url in
                audioNoteRow(url: url, index: index)
            }
        }
    }
    
    private var audioNotesSectionHeader: some View {
        HStack {
            Text("Audio Notes")
            Spacer()
            if !audioNotes.isEmpty {
                Text("\(audioNotes.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var recordButton: some View {
        Button {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } label: {
            HStack {
                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .foregroundColor(isRecording ? .red : .accentColor)
                Text(isRecording ? "Stop Recording" : "Record Audio Note")
                if isRecording {
                    Spacer()
                    Text(formatDuration(recordingDuration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
    }
    
    private var emptyAudioState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No audio notes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            Spacer()
        }
    }
    
    private func audioNoteRow(url: URL, index: Int) -> some View {
        HStack {
            Button {
                toggleAudioPlayback(url: url)
            } label: {
                Image(systemName: playingAudioURL == url ? "pause.circle.fill" : "play.circle.fill")
                    .foregroundColor(.accentColor)
            }
            .accessibilityLabel(playingAudioURL == url ? "Pause audio" : "Play audio")
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Audio Note \(index + 1)")
                    .font(.subheadline)
                if let duration = getAudioDuration(url: url) {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                audioToDelete = url
                showDeleteAudioAlert = true
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .accessibilityLabel("Delete audio note")
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                saveTrip()
            }
            .disabled(!isFormValid || isSaving)
            .accessibilityLabel("Save trip")
        }
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
            .disabled(isSaving)
            .accessibilityLabel("Cancel editing")
        }
        
        ToolbarItem(placement: .keyboard) {
            HStack {
                Spacer()
                Button("Done") {
                    hideKeyboard()
                }
            }
        }
    }
    
    @ViewBuilder
    private var savingOverlay: some View {
        if isSaving {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("Saving...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
            }
        }
    }
    
    @ViewBuilder
    private var photoSourceDialogContent: some View {
        Button("Take Photo") {
            imagePickerSourceType = .camera
            showImagePicker = true
        }
        Button("Choose from Library") {
            showPhotoPicker = true
        }
        Button("Cancel", role: .cancel) {}
    }
    
    // MARK: - Helper Methods
    
    private func loadPhotos(from items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImages.append(image)
                }
            }
            photoPickerItems = []
        }
    }

    // MARK: - Setup & Cleanup
    
    private func setupView() {
        selectedImages = trip.photoURLs.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let img = UIImage(data: data) else { return nil }
            return img
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
        
        configureAudioSession()
    }
    
    private func cleanup() {
        recordingTimer?.invalidate()
        audioRecorder?.stop()
        audioPlayer?.stop()
        deactivateAudioSession()
    }
    
    // MARK: - Audio Session Management
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
    
    // MARK: - Audio Recording
    
    private func startRecording() {
        let docDir = FileManager.default.temporaryDirectory
        let url = docDir.appendingPathComponent(UUID().uuidString + ".m4a")
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    do {
                        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
                        audioRecorder?.record()
                        isRecording = true
                        recordingDuration = 0
                        startRecordingTimer()
                    } catch {
                        print("Failed to start recording: \(error)")
                    }
                } else {
                    validationMessage = "Microphone access is required to record audio notes."
                    showValidationError = true
                }
            }
        }
    }
    
    private func stopRecording() {
        recordingTimer?.invalidate()
        audioRecorder?.stop()
        if let url = audioRecorder?.url {
            audioNotes.append(url)
        }
        isRecording = false
        recordingDuration = 0
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
    }
    
    // MARK: - Audio Playback
    
    private func toggleAudioPlayback(url: URL) {
        if playingAudioURL == url {
            stopAudioPlayback()
        } else {
            playAudio(url: url)
        }
    }
    
    private func playAudio(url: URL) {
        do {
            stopAudioPlayback()
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            playingAudioURL = url
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (audioPlayer?.duration ?? 0)) {
                if playingAudioURL == url {
                    playingAudioURL = nil
                }
            }
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
    
    private func stopAudioPlayback() {
        audioPlayer?.stop()
        playingAudioURL = nil
    }
    
    private func getAudioDuration(url: URL) -> TimeInterval? {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            return player.duration
        } catch {
            return nil
        }
    }
    
    // MARK: - Save Trip
    
    private func saveTrip() {
        guard isFormValid else {
            validationMessage = "Please fill in all required fields."
            showValidationError = true
            return
        }
        
        isSaving = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            for oldURL in trip.photoURLs {
                try? FileManager.default.removeItem(at: oldURL)
            }
            
            if selectedReason == "Other" {
                trip.reason = customReason.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                trip.reason = selectedReason
            }
            
            trip.photoURLs = selectedImages.compactMap { image in
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
                do {
                    try data.write(to: url)
                    return url
                } catch {
                    print("Failed to save image: \(error)")
                    return nil
                }
            }
            
            trip.audioNotes = audioNotes
            
            DispatchQueue.main.async {
                isSaving = false
                onSave(trip)
                dismiss()
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func cleanupAudioFile(url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Full Image View

struct FullImageView: View {
    let image: UIImage
    let onClose: () -> Void
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                    .accessibilityLabel("Close image")
                }
                
                Spacer()
                
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale < 1.0 {
                                    withAnimation {
                                        scale = 1.0
                                        lastScale = 1.0
                                    }
                                } else if scale > 3.0 {
                                    withAnimation {
                                        scale = 3.0
                                        lastScale = 3.0
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation {
                            if scale > 1.0 {
                                scale = 1.0
                                lastScale = 1.0
                            } else {
                                scale = 2.0
                                lastScale = 2.0
                            }
                        }
                    }
                
                Spacer()
            }
        }
    }
}

// MARK: - UIImage Extension

extension UIImage: Identifiable {
    public var id: String {
        self.pngData()?.base64EncodedString() ?? UUID().uuidString
    }
}

// MARK: - TripImagePicker

struct TripImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    var onImagePicked: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: TripImagePicker
        
        init(_ parent: TripImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }
    }
}
