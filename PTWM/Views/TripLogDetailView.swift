// TripLogDetailView.swift
// Enhanced version with improved UI, sharing, export, and interactive features

import SwiftUI
import MapKit

struct TripLogDetailView: View {
    @State var trip: Trip
    @Environment(\.dismiss) private var dismiss
    @AppStorage("useKilometers") private var useKilometers: Bool = false
    @AppStorage("gasPricePerGallon") private var gasPricePerGallon: Double = 3.99
    @EnvironmentObject var tripManager: TripManager
    @State private var editingTrip: Trip?
    @State private var showingShareSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var selectedPhotoURL: URL?
    @State private var showingFullScreenPhoto = false
    @State private var expandedSections: Set<String> = ["details"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header Card with Trip Summary
                    tripHeaderCard
                    
                    // Map Section
                    if trip.routeCoordinates.count >= 2 {
                        mapSection
                    }
                    
                    if trip.routeCoordinates.count >= 2 {
                        interactiveMapSection
                    }
                    
                    // Trip Statistics Card
                    statisticsCard
                    
                    // Category and Notes Section
                    if !trip.reason.isEmpty || !trip.notes.isEmpty {
                        infoCard
                    }
                    
                    // Financial Information
                    if fuelUsedForTrip != nil || !trip.pay.isEmpty {
                        financialCard
                    }
                    
                    // Media Section
                    if !trip.photoURLs.isEmpty {
                        photosSection
                    }
                    
                    if !trip.audioNotes.isEmpty {
                        audioNotesSection
                    }
                    
                    // Additional Metadata
                    if trip.isRecovered {
                        recoveryBanner
                    }
                }
                .padding()
            }
            .navigationTitle("Trip Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { editingTrip = trip }) {
                            Label("Edit Trip", systemImage: "pencil")
                        }
                        Button(action: { showingShareSheet = true }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Button(action: exportTripData) {
                            Label("Export Data", systemImage: "arrow.down.doc")
                        }
                        Divider()
                        Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                            Label("Delete Trip", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $editingTrip) { editing in
                TripEditView(trip: trip) { updatedTrip in
                    trip = updatedTrip
                    tripManager.updateTrip(updatedTrip)
                    editingTrip = nil
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [generateShareText()])
            }
            .fullScreenCover(isPresented: $showingFullScreenPhoto) {
                if let photoURL = selectedPhotoURL {
                    PhotoDetailView(photoURL: photoURL, isPresented: $showingFullScreenPhoto)
                }
            }
            .alert("Delete Trip", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let idx = tripManager.trips.firstIndex(where: { $0.id == trip.id }) {
                        tripManager.deleteTrip(at: IndexSet(integer: idx))
                    } else {
                        // Fallback: try a direct delete if supported by TripManager
                        #if compiler(>=5.7)
                        _ = { (manager: Any) in
                            // no-op shim to keep compile-time only
                        }(tripManager)
                        #endif
                    }
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this trip? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - TripLogDetailView Statistics Card Fix
    
    private var calculatedAverageSpeed: Double {
            if let avgSpeed = trip.averageSpeed, avgSpeed > 0 {
                return avgSpeed
            }
            let duration = trip.endTime.timeIntervalSince(trip.startTime)
            guard duration > 0 else { return 0 }
            let distanceMeters = trip.distance * 1609.34
            return distanceMeters / duration
        }
        
        private var statisticsCard: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Statistics")
                    .font(.headline)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatItem(
                        icon: "speedometer",
                        title: "Distance",
                        value: DistanceFormatterHelper.string(for: trip.distance, useKilometers: useKilometers),
                        color: .blue
                    )
                    
                    StatItem(
                        icon: "clock",
                        title: "Duration",
                        value: formattedDuration(from: trip.startTime, to: trip.endTime),
                        color: .green
                    )
                    
                    StatItem(
                        icon: "gauge",
                        title: "Avg Speed",
                        value: AverageSpeedFormatter.string(forMetersPerSecond: calculatedAverageSpeed, useKilometers: useKilometers),
                        color: .orange
                    )
                    
                    if let fuelGallons = fuelUsedForTrip {
                        StatItem(
                            icon: "fuelpump",
                            title: "Fuel Used",
                            value: String(format: "%.2f gal", fuelGallons),
                            color: .red
                        )
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        
        private func formattedDuration(from start: Date, to end: Date) -> String {
            let interval = Int(end.timeIntervalSince(start))
            let hours = interval / 3600
            let minutes = (interval % 3600) / 60
            let seconds = interval % 60
            
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else if minutes > 0 {
                return "\(minutes)m"
            } else {
                return "\(seconds)s"
            }
        }
    
    // MARK: - View Components
    
    private var tripHeaderCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.startTime.formatted(date: .abbreviated, time: .omitted))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(trip.startTime.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: tripIconName)
                    .font(.title)
                    .foregroundColor(.accentColor)
            }
            
            if let duration = tripDuration {
                Text(duration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Route")
                .font(.headline)
            
            TripSummaryMap(trip: trip)
                .frame(height: 300)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trip Information")
                .font(.headline)
            
            if !trip.reason.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.accentColor)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Category")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(trip.reason)
                            .font(.body)
                    }
                }
            }
            
            if !trip.notes.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "note.text")
                        .foregroundColor(.accentColor)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(trip.notes)
                            .font(.body)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var financialCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Financial")
                .font(.headline)
            
            if let fuelGallons = fuelUsedForTrip, gasPricePerGallon > 0 {
                let cost = fuelGallons * gasPricePerGallon
                HStack {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(.green)
                    Text("Fuel Cost")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "$%.2f", cost))
                        .fontWeight(.semibold)
                }
            }
            
            if !trip.pay.isEmpty {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .foregroundColor(.blue)
                    Text("Payment")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(trip.pay)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photos")
                    .font(.headline)
                Spacer()
                Text("\(trip.photoURLs.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(trip.photoURLs, id: \.self) { url in
                        if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                            Button(action: {
                                selectedPhotoURL = url
                                showingFullScreenPhoto = true
                            }) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                    .shadow(radius: 3)
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var audioNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Audio Notes")
                    .font(.headline)
                Spacer()
                Text("\(trip.audioNotes.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            }
            
            ForEach(Array(trip.audioNotes.enumerated()), id: \.element) { index, url in
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.accentColor)
                    Text(url.lastPathComponent)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Button(action: {
                        // Play audio note
                    }) {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var recoveryBanner: some View {
        HStack {
            Image(systemName: "arrow.clockwise.circle.fill")
                .foregroundColor(.orange)
            Text("This trip was recovered after app termination")
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Properties
    
    private var fuelUsedForTrip: Double? {
        let mpg: Double
        if let avgSpeed = trip.averageSpeed {
            if avgSpeed >= 22.35 { // 50 mph in m/s
                mpg = tripManager.highwayMPG
            } else {
                mpg = tripManager.cityMPG
            }
        } else {
            mpg = tripManager.cityMPG
        }
        guard mpg > 0 else { return nil }
        return tripManager.fuelUsed(for: trip.distance, mpg: mpg)
    }
    
    private var tripIconName: String {
        if !trip.reason.isEmpty {
            switch trip.reason.lowercased() {
            case "work": return "briefcase.fill"
            case "personal": return "house.fill"
            case "business": return "building.2.fill"
            default: return "car.fill"
            }
        }
        return "car.fill"
    }
    
    private var tripDuration: String? {
        formattedDuration(from: trip.startTime, to: trip.endTime)
    }
    
    // MARK: - Helper Methods
    
    private func generateShareText() -> String {
        var text = "Trip Summary\n\n"
        text += "Date: \(trip.startTime.formatted(date: .long, time: .omitted))\n"
        text += "Time: \(trip.startTime.formatted(date: .omitted, time: .shortened)) - \(trip.endTime.formatted(date: .omitted, time: .shortened))\n"
        text += "Distance: \(DistanceFormatterHelper.string(for: trip.distance, useKilometers: useKilometers))\n"
        text += "Duration: \(formattedDuration(from: trip.startTime, to: trip.endTime))\n"
        
        if let avgSpeed = trip.averageSpeed {
            text += "Average Speed: \(AverageSpeedFormatter.string(forMetersPerSecond: avgSpeed, useKilometers: useKilometers))\n"
        }
        
        if !trip.reason.isEmpty {
            text += "Category: \(trip.reason)\n"
        }
        
        if let fuelGallons = fuelUsedForTrip, gasPricePerGallon > 0 {
            let cost = fuelGallons * gasPricePerGallon
            text += "Fuel Cost: $\(String(format: "%.2f", cost))\n"
        }
        
        return text
    }
    
    private func exportTripData() {
        // Implement CSV or JSON export functionality
        let exportData = generateShareText()
        UIPasteboard.general.string = exportData
        // Show a success message or save to file
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct PhotoDetailView: View {
    let photoURL: URL
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let data = try? Data(contentsOf: photoURL), let img = UIImage(data: data) {
                Image(uiImage: img)
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
                                if scale < 1 {
                                    withAnimation {
                                        scale = 1
                                        lastScale = 1
                                    }
                                }
                            }
                    )
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}

extension Array where Element == CodableCoordinate {
    var clCoordinates: [CLLocationCoordinate2D] {
        map { $0.clCoordinate }
    }
}

extension TripLogDetailView {
    var interactiveMapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Interactive Route Playback")
                .font(.headline)
            
            NavigationLink(destination: FullScreenRoutePlaybackView(trip: trip)) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scrub through your trip")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text("View speed and time at any point")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
}

struct FullScreenRoutePlaybackView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPointIndex: Int? = nil
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            InteractiveTripMapView(trip: trip, selectedPointIndex: $selectedPointIndex)
                .ignoresSafeArea()
            
            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.5)))
                    .padding()
            }
        }
        .navigationBarHidden(true)
    }
}
