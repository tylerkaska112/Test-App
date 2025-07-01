import SwiftUI
import MapKit
import UniformTypeIdentifiers
import AVFoundation


struct TripLogView: View {
    @EnvironmentObject var tripManager: TripManager
    @State private var expandedTripID: UUID? = nil
    @State private var editingTrip: Trip? = nil
    @State private var showShareSheet = false
    @State private var exportURL: URL? = nil
    @AppStorage("useKilometers") private var useKilometers: Bool = false

    @State private var audioPlayer: AVAudioPlayer? = nil
    @State private var showAudioErrorAlert = false
    @State private var audioErrorMessage = ""
    
    @State private var selectedFullImage: UIImage? = nil
    
    @State private var selectedTripIDs: Set<UUID> = []
    
    @State private var sortOption: SortOption = .dateDescending
    
    @State private var showDeleteConfirmation = false
    
    @State private var searchText: String = ""
    
    enum SortOption: String, CaseIterable, Identifiable {
        case dateDescending = "Date (Newest)"
        case dateAscending = "Date (Oldest)"
        case distanceDescending = "Distance (Longest)"
        case distanceAscending = "Distance (Shortest)"
        case timeDescending = "Time (Longest)"
        case timeAscending = "Time (Shortest)"
        var id: String { rawValue }
    }
    
    var selectedTrips: [Trip] {
        tripManager.trips.filter { selectedTripIDs.contains($0.id) }
    }
    
    var sortedTrips: [Trip] {
        switch sortOption {
        case .dateDescending:
            return tripManager.trips.sorted { $0.startTime > $1.startTime }
        case .dateAscending:
            return tripManager.trips.sorted { $0.startTime < $1.startTime }
        case .distanceDescending:
            return tripManager.trips.sorted { $0.distance > $1.distance }
        case .distanceAscending:
            return tripManager.trips.sorted { $0.distance < $1.distance }
        case .timeDescending:
            return tripManager.trips.sorted {
                $0.endTime.timeIntervalSince($0.startTime) > $1.endTime.timeIntervalSince($1.startTime)
            }
        case .timeAscending:
            return tripManager.trips.sorted {
                $0.endTime.timeIntervalSince($0.startTime) < $1.endTime.timeIntervalSince($1.startTime)
            }
        }
    }
    
    // Now filters by notes or reason
    var filteredTrips: [Trip] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return sortedTrips }
        return sortedTrips.filter {
            $0.notes.range(of: searchText, options: .caseInsensitive) != nil ||
            $0.reason.range(of: searchText, options: .caseInsensitive) != nil
        }
    }
    
    var body: some View {
        BackgroundWrapper {
            VStack {
                TextField("Search notes or category...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)
                    .padding([.horizontal, .top])
                
                
                Button(action: { exportTripLogsToCSV(selected: selectedTrips) }) {
                    Label("Export as CSV", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .disabled(selectedTripIDs.isEmpty)
                
                Button(action: { showDeleteConfirmation = true }) {
                    Label("Delete Selected Logs", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.bottom, 5)
                .frame(maxWidth: .infinity)
                .disabled(selectedTripIDs.isEmpty)
                
                HStack {
                    Spacer()
                    Menu {
                        ForEach(SortOption.allCases) { option in
                            Button(option.rawValue) { sortOption = option }
                        }
                    } label: {
                        Label("Sort by: \(sortOption.rawValue)", systemImage: "arrow.up.arrow.down")
                            .font(.subheadline.bold())
                    }
                    .padding(.trailing)
                }
                
                List(selection: $selectedTripIDs) {
                    ForEach(filteredTrips) { trip in
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.ultraThinMaterial)
                            if selectedTripIDs.contains(trip.id) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.accentColor.opacity(0.15))
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                if trip.isRecovered {
                                    HStack {
                                        Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                                            .foregroundColor(.orange)
                                        Text("Recovered after app termination")
                                            .font(.subheadline)
                                            .foregroundColor(.orange)
                                            .bold()
                                    }
                                }
                                
                                Text("Trip Start: \(trip.startTime.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.headline)
                                Text("Trip End: \(trip.endTime.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.subheadline)
                                Text("Distance: \(DistanceFormatterHelper.string(for: trip.distance, useKilometers: useKilometers))")
                                
                                // Drive Duration line after Distance
                                Text("Drive Duration: \(formattedDuration(from: trip.startTime, to: trip.endTime))")
                                
                                if !trip.reason.isEmpty {
                                    Text("Reason: \(trip.reason)")
                                }
                                
                                if !trip.notes.isEmpty {
                                    Text("Notes: \(trip.notes)")
                                        .italic()
                                        .accessibilityLabel("Notes")
                                }
                                
                                if !trip.pay.isEmpty {
                                    Text("Pay: \(trip.pay)")
                                        .bold()
                                        .accessibilityLabel("Pay")
                                }
                                
                                if !trip.photoURLs.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Photos:")
                                            .font(.subheadline)
                                            .bold()
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 10) {
                                                ForEach(trip.photoURLs, id: \.self) { url in
                                                    if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                                                        Button {
                                                            selectedFullImage = img
                                                        } label: {
                                                            Image(uiImage: img)
                                                                .resizable()
                                                                .frame(width: 70, height: 70)
                                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // Audio notes buttons
                                if !trip.audioNotes.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Audio Notes:")
                                            .font(.subheadline)
                                            .bold()
                                        ForEach(trip.audioNotes, id: \.self) { audioURL in
                                            Button(action: {
                                                playAudio(from: audioURL)
                                            }) {
                                                Label("Play Audio Note", systemImage: "play.circle")
                                            }
                                            .buttonStyle(.bordered)
                                            .accessibilityLabel("Play audio note")
                                        }
                                    }
                                }
                                
                                HStack {
                                    Button(expandedTripID == trip.id ? "Hide Map" : "Show Map") {
                                        expandedTripID = expandedTripID == trip.id ? nil : trip.id
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel(expandedTripID == trip.id ? "Hide map" : "Show map")
                                    
                                    Spacer()
                                    
                                    Button("Edit") {
                                        editingTrip = trip
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Edit trip")
                                }
                                
                                if expandedTripID == trip.id {
                                    TripSummaryMap(trip: trip)
                                        .frame(height: 300)
                                }
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal)
                        }
                    }
                    .onDelete(perform: deleteTrip)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .navigationTitle("Trip Log")
                .toolbar {
                    Button("Export CSV") {
                        exportTripLogsToCSV(selected: selectedTrips)
                    }
                    .disabled(selectedTripIDs.isEmpty)
                }
                .environment(\.editMode, .constant(.active))
                .sheet(isPresented: $showShareSheet) {
                    if let url = exportURL {
                        ShareSheet(activityItems: [url])
                    }
                }
                .sheet(item: $editingTrip) { trip in
                    TripEditView(trip: trip) { updatedTrip in
                        tripManager.updateTrip(updatedTrip)
                    }
                }
                .alert("Audio Playback Error", isPresented: $showAudioErrorAlert, actions: {
                    Button("OK", role: .cancel) { }
                }, message: {
                    Text(audioErrorMessage)
                })
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
            .alert("Delete Selected Logs?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { deleteSelectedTrips() }
            } message: {
                Text("This action is permanent and cannot be undone. Are you sure you want to delete the selected logs?")
            }
        }
    }
    
    func deleteTrip(at offsets: IndexSet) {
        tripManager.deleteTrip(at: offsets)
    }
    
    private func deleteSelectedTrips() {
        let indices = tripManager.trips.enumerated().filter { selectedTripIDs.contains($0.element.id) }.map { $0.offset }
        let indexSet = IndexSet(indices)
        tripManager.deleteTrip(at: indexSet)
        selectedTripIDs.removeAll()
    }
    
    func exportTripLogsToCSV(selected: [Trip]) {
        let unit = useKilometers ? "kilometers" : "miles"
        let header = "Start Time,End Time,Distance (\(unit)),Notes,Pay\n"
        let rows = selected.map { trip in
            let distString = DistanceFormatterHelper.string(for: trip.distance, useKilometers: useKilometers)
                .replacingOccurrences(of: " mi", with: "")
                .replacingOccurrences(of: " km", with: "")
            return "\(trip.startTime),\(trip.endTime),\(distString),\(trip.notes),\(trip.pay)"
        }.joined(separator: "\n")
        
        let csvString = header + rows
        
        do {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("TripLogs.csv")
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            exportURL = tempURL
            showShareSheet = true
        } catch {
            print("Failed to create CSV file: \(error)")
        }
    }
    
    private func playAudio(from url: URL) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            audioErrorMessage = "Audio session setup failed: \(error.localizedDescription)"
            showAudioErrorAlert = true
            return
        }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            audioErrorMessage = "Unable to play audio note: \(error.localizedDescription)"
            showAudioErrorAlert = true
        }
    }
    
    private func formattedDuration(from start: Date, to end: Date) -> String {
        let interval = Int(end.timeIntervalSince(start))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}


struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
