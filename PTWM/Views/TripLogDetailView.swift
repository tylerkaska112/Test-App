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
    @State private var selectedPhotoIndex: Int = 0
    @State private var showingFullScreenPhoto = false
    @State private var expandedSections: Set<String> = ["details"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    tripHeaderCard
                    
                    if trip.routeCoordinates.count >= 2 {
                        mapSection
                    }
                    
                    if trip.routeCoordinates.count >= 2 {
                        interactiveMapSection
                    }
                    
                    statisticsCard
                    
                    if !trip.reason.isEmpty || !trip.notes.isEmpty {
                        infoCard
                    }
                    
                    if fuelUsedForTrip != nil || !trip.pay.isEmpty {
                        financialCard
                    }
                    
                    if !trip.photoURLs.isEmpty {
                        updatedPhotosSection
                    }
                    
                    if !trip.audioNotes.isEmpty {
                        audioNotesSection
                    }
                    
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
                EnhancedPhotoDetailView(
                    photoURLs: trip.photoURLs,
                    initialIndex: selectedPhotoIndex,
                    isPresented: $showingFullScreenPhoto
                )
            }
            .alert("Delete Trip", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let idx = tripManager.trips.firstIndex(where: { $0.id == trip.id }) {
                        tripManager.deleteTrip(at: IndexSet(integer: idx))
                    } else {
                        #if compiler(>=5.7)
                        _ = { (manager: Any) in
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
    
    private var updatedPhotosSection: some View {
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
                    ForEach(Array(trip.photoURLs.enumerated()), id: \.element) { index, url in
                        Button(action: {
                            selectedPhotoIndex = index
                            showingFullScreenPhoto = true
                        }) {
                            ThumbnailImage(url: url)
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
    
    private var interactiveMapSection: some View {
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
    
    // MARK: - Helper Properties
    
    private var fuelUsedForTrip: Double? {
        let mpg: Double
        if let avgSpeed = trip.averageSpeed {
            if avgSpeed >= 22.35 {
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
        let exportData = generateShareText()
        UIPasteboard.general.string = exportData
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

struct EnhancedPhotoDetailView: View {
    let photoURLs: [URL]
    let initialIndex: Int
    @Binding var isPresented: Bool
    @State private var currentIndex: Int
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isLoading = true
    @State private var loadError = false
    
    init(photoURLs: [URL], initialIndex: Int, isPresented: Binding<Bool>) {
        self.photoURLs = photoURLs
        self.initialIndex = initialIndex
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            } else if loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    Text("Failed to load image")
                        .foregroundColor(.white)
                }
            } else if let image = image {
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .scaleEffect(scale)
                        .offset(x: offset.width, y: offset.height)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1), 10)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    withAnimation(.spring(response: 0.3)) {
                                        if scale < 1 {
                                            scale = 1
                                            offset = .zero
                                            lastOffset = .zero
                                        } else {
                                            offset = constrainOffset(geometry: geometry)
                                            lastOffset = offset
                                        }
                                    }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    if scale > 1 {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.spring(response: 0.3)) {
                                        offset = constrainOffset(geometry: geometry)
                                        lastOffset = offset
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.3)) {
                                if scale > 1 {
                                    scale = 1
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 3
                                }
                            }
                        }
                }
            }
            
            if photoURLs.count > 1 && scale <= 1 {
                HStack {
                    if currentIndex > 0 {
                        Button(action: { goToPrevious() }) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                        }
                        .padding(.leading, 20)
                    }
                    
                    Spacer()
                    
                    if currentIndex < photoURLs.count - 1 {
                        Button(action: { goToNext() }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                        }
                        .padding(.trailing, 20)
                    }
                }
            }
            
            VStack {
                HStack {
                    if photoURLs.count > 1 {
                        Text("\(currentIndex + 1) / \(photoURLs.count)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(20)
                            .padding(.leading)
                    }
                    
                    Spacer()
                    
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                            .padding()
                    }
                }
                Spacer()
                
                if !isLoading && !loadError && scale > 1 {
                    Text("Pinch to zoom • Drag to pan • Double-tap to reset")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                        .padding(.bottom, 20)
                } else if !isLoading && !loadError && photoURLs.count > 1 {
                    Text("Swipe or tap arrows to navigate • Double-tap to zoom")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                        .padding(.bottom, 20)
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if scale <= 1 {
                        if value.translation.width < -50 {
                            goToNext()
                        } else if value.translation.width > 50 {
                            goToPrevious()
                        }
                    }
                }
        )
        .onAppear {
            loadImageAsync()
        }
        .onChange(of: currentIndex) { _ in
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
            isLoading = true
            loadError = false
            image = nil
            loadImageAsync()
        }
    }
    
    private func goToNext() {
        if currentIndex < photoURLs.count - 1 {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentIndex += 1
            }
        }
    }
    
    private func goToPrevious() {
        if currentIndex > 0 {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentIndex -= 1
            }
        }
    }
    
    private func loadImageAsync() {
        let photoURL = photoURLs[currentIndex]
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = try? Data(contentsOf: photoURL) else {
                DispatchQueue.main.async {
                    isLoading = false
                    loadError = true
                }
                return
            }
            
            guard let loadedImage = UIImage(data: data) else {
                DispatchQueue.main.async {
                    isLoading = false
                    loadError = true
                }
                return
            }
            
            let downsampledImage: UIImage
            if loadedImage.size.width > 4096 || loadedImage.size.height > 4096 {
                downsampledImage = downsample(image: loadedImage, to: CGSize(width: 4096, height: 4096))
            } else {
                downsampledImage = loadedImage
            }
            
            DispatchQueue.main.async {
                self.image = downsampledImage
                isLoading = false
            }
        }
    }
    
    private func downsample(image: UIImage, to targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    private func constrainOffset(geometry: GeometryProxy) -> CGSize {
        guard let image = image else { return .zero }
        
        let imageSize = image.size
        let viewSize = geometry.size
        
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        let displaySize: CGSize
        if imageAspect > viewAspect {
            displaySize = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
        } else {
            displaySize = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
        }
        
        let scaledWidth = displaySize.width * scale
        let scaledHeight = displaySize.height * scale
        
        let maxOffsetX = max(0, (scaledWidth - viewSize.width) / 2)
        let maxOffsetY = max(0, (scaledHeight - viewSize.height) / 2)
        
        return CGSize(
            width: min(max(offset.width, -maxOffsetX), maxOffsetX),
            height: min(max(offset.height, -maxOffsetY), maxOffsetY)
        )
    }
}

struct ThumbnailImage: View {
    let url: URL
    @State private var thumbnail: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let cacheKey = url.lastPathComponent
        if let cached = ThumbnailCache.shared.get(cacheKey) {
            self.thumbnail = cached
            self.isLoading = false
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }
            
            let thumbSize = CGSize(width: 240, height: 240)
            let thumb = createThumbnail(from: image, size: thumbSize)
            
            DispatchQueue.main.async {
                ThumbnailCache.shared.set(thumb, forKey: cacheKey)
                self.thumbnail = thumb
                self.isLoading = false
            }
        }
    }
    
    private func createThumbnail(from image: UIImage, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

class ThumbnailCache {
    static let shared = ThumbnailCache()
    private var cache: [String: UIImage] = [:]
    private let queue = DispatchQueue(label: "thumbnail.cache", attributes: .concurrent)
    
    func get(_ key: String) -> UIImage? {
        queue.sync {
            cache[key]
        }
    }
    
    func set(_ image: UIImage, forKey key: String) {
        queue.async(flags: .barrier) {
            self.cache[key] = image
        }
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}

extension Array where Element == CodableCoordinate {
    var clCoordinates: [CLLocationCoordinate2D] {
        map { $0.clCoordinate }
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
