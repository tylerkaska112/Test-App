//
//  TripRouteScrubbingView.swift
//  waylon
//
//  Created by Tyler Kaska on 10/15/25.
//

import SwiftUI
import MapKit
import AVFoundation

// MARK: - Route Point Model
struct RoutePoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
    let speed: Double // in m/s
    let distanceFromStart: Double // in miles
    
    var speedMPH: Double {
        speed * 2.23694
    }
    
    var speedKMH: Double {
        speed * 3.6
    }
}

// MARK: - Trip Event Model
enum TripEvent: Identifiable {
    case fastestSpeed(index: Int, speed: Double)
    case longestStop(index: Int, duration: TimeInterval)
    case significantSpeedChange(index: Int, change: Double)
    
    var id: String {
        switch self {
        case .fastestSpeed(let index, _): return "fastest_\(index)"
        case .longestStop(let index, _): return "stop_\(index)"
        case .significantSpeedChange(let index, _): return "change_\(index)"
        }
    }
    
    var title: String {
        switch self {
        case .fastestSpeed(_, let speed): return "Fastest: \(Int(speed * 2.23694)) mph"
        case .longestStop(_, let duration): return "Stop: \(Int(duration / 60)) min"
        case .significantSpeedChange: return "Speed Change"
        }
    }
    
    var icon: String {
        switch self {
        case .fastestSpeed: return "speedometer"
        case .longestStop: return "pause.circle.fill"
        case .significantSpeedChange: return "arrow.up.arrow.down"
        }
    }
    
    var index: Int {
        switch self {
        case .fastestSpeed(let index, _): return index
        case .longestStop(let index, _): return index
        case .significantSpeedChange(let index, _): return index
        }
    }
}

// MARK: - Interactive Trip Map with Scrubbing
struct InteractiveTripMapView: View {
    let trip: Trip
    @Binding var selectedPointIndex: Int?
    @AppStorage("useKilometers") private var useKilometers: Bool = false
    
    @State private var routePoints: [RoutePoint] = []
    @State private var isPlaying: Bool = false
    @State private var playbackSpeed: Double = 1.0
    @State private var playbackTimer: Timer?
    @State private var hasInitiallyFitRoute: Bool = false
    @State private var showOverlay: Bool = true
    @State private var scrubSensitivity: Int = 1
    @State private var tripEvents: [TripEvent] = []
    @State private var showEventsMenu: Bool = false
    @State private var rotateWithDirection: Bool = false
    @State private var isExporting: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var shareContent: String = ""
    @State private var showExportAlert: Bool = false
    @State private var exportProgress: Double = 0.0
    @State private var exportedVideoURL: URL?
    
    var selectedPoint: RoutePoint? {
        guard let index = selectedPointIndex, index < routePoints.count else { return nil }
        return routePoints[index]
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrubbableMapView(
                trip: trip,
                routePoints: routePoints,
                selectedPointIndex: $selectedPointIndex,
                hasInitiallyFitRoute: $hasInitiallyFitRoute,
                rotateWithDirection: rotateWithDirection
            )
            .ignoresSafeArea()
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { gesture in
                        handleSwipeGesture(translation: gesture.translation.width)
                    }
            )
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: { showEventsMenu.toggle() }) {
                        Image(systemName: "star.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                            .padding()
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    
                    Spacer()
                    
                    Button(action: { withAnimation { showOverlay.toggle() } }) {
                        Image(systemName: showOverlay ? "eye.fill" : "eye.slash.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                            .padding()
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    
                    Button(action: { rotateWithDirection.toggle() }) {
                        Image(systemName: rotateWithDirection ? "location.north.line.fill" : "location.north.line")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                            .padding()
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    
                    Menu {
                        Button(action: shareCurrentMoment) {
                            Label("Share Current Moment", systemImage: "square.and.arrow.up")
                        }
                        Button(action: exportTripVideo) {
                            Label("Export Trip Video", systemImage: "video.badge.plus")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                            .padding()
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 60)
                
                if let point = selectedPoint, showOverlay {
                    pointInfoCard(point: point)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
                
                scrubbingControls
                    .background(.ultraThinMaterial)
                    .cornerRadius(16, corners: [.topLeft, .topRight])
            }
            
            if showEventsMenu {
                eventsMenu
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let videoURL = exportedVideoURL {
                ShareSheet(items: [videoURL])
            } else {
                ShareSheet(items: [shareContent])
            }
        }
        .alert("Export Complete", isPresented: $showExportAlert) {
            Button("Save to Files", role: .none) {
                if let videoURL = exportedVideoURL {
                    saveVideoToFiles(url: videoURL)
                }
            }
            Button("Share", role: .none) {
                if let videoURL = exportedVideoURL {
                    shareContent = ""
                    showShareSheet = true
                }
            }
            Button("OK", role: .cancel) {
                exportedVideoURL = nil
            }
        } message: {
            if exportedVideoURL != nil {
                Text("Your trip video has been created successfully! You can save it to Files or share it.")
            } else {
                Text("Failed to create video. Please try again.")
            }
        }
        .overlay(
            Group {
                if isExporting {
                    exportProgressView
                }
            }
        )
        .onAppear {
            generateRoutePoints()
            analyzeTrip()
        }
        .onDisappear {
            stopPlayback()
        }
    }
    
    private var exportProgressView: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView(value: exportProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                    .frame(width: 200)
                
                Text("Exporting video...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(Int(exportProgress * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(30)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
    }
    
    private var eventsMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Trip Events")
                    .font(.headline)
                    .padding()
                
                Spacer()
                
                Button(action: { showEventsMenu = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(tripEvents) { event in
                        Button(action: {
                            jumpToEvent(event)
                            showEventsMenu = false
                        }) {
                            HStack {
                                Image(systemName: event.icon)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 30)
                                
                                Text(event.title)
                                    .font(.body)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(radius: 20)
        .padding(.leading, 20)
        .padding(.vertical, 100)
    }
    
    private func pointInfoCard(point: RoutePoint) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(point.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.headline)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("Speed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.caption)
                        Text(formatSpeed(point.speed))
                            .font(.headline)
                    }
                    .foregroundColor(speedColor(point.speedMPH))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("From Start")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDistance(point.distanceFromStart))
                        .font(.headline)
                }
            }
            
            HStack(spacing: 8) {
                Text("Progress:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 6)
                        
                        if let index = selectedPointIndex, !routePoints.isEmpty {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentColor)
                                .frame(
                                    width: geometry.size.width * CGFloat(index) / CGFloat(routePoints.count - 1),
                                    height: 6
                                )
                        }
                    }
                }
                .frame(height: 6)
                
                if let index = selectedPointIndex {
                    Text("\(Int((Double(index) / Double(max(routePoints.count - 1, 1))) * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(radius: 8)
        .padding(.horizontal)
    }
    
    private var scrubbingControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                Button(action: skipToStart) {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                }
                .disabled(routePoints.isEmpty)
                
                Button(action: stepBackward) {
                    Image(systemName: "backward.frame.fill")
                        .font(.title2)
                }
                .disabled(selectedPointIndex == nil || selectedPointIndex == 0)
                
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.accentColor)
                }
                .disabled(routePoints.isEmpty)
                
                Button(action: stepForward) {
                    Image(systemName: "forward.frame.fill")
                        .font(.title2)
                }
                .disabled(selectedPointIndex == nil || selectedPointIndex == routePoints.count - 1)
                
                Button(action: skipToEnd) {
                    Image(systemName: "forward.end.fill")
                        .font(.title2)
                }
                .disabled(routePoints.isEmpty)
            }
            .padding(.horizontal)
            
            if !routePoints.isEmpty {
                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { Double(selectedPointIndex ?? 0) },
                            set: { newValue in
                                let targetIndex = Int(newValue)
                                if targetIndex != selectedPointIndex {
                                    selectedPointIndex = targetIndex
                                    triggerHapticFeedback()
                                }
                            }
                        ),
                        in: 0...Double(routePoints.count - 1),
                        step: Double(scrubSensitivity)
                    )
                    .accentColor(.accentColor)
                    
                    HStack {
                        Text(trip.startTime.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(trip.endTime.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Speed:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        ForEach([0.5, 1.0, 2.0, 4.0], id: \.self) { speed in
                            Button(action: { playbackSpeed = speed }) {
                                Text("\(speed, specifier: "%.1f")x")
                                    .font(.caption)
                                    .fontWeight(playbackSpeed == speed ? .bold : .regular)
                                    .foregroundColor(playbackSpeed == speed ? .accentColor : .secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(playbackSpeed == speed ? Color.accentColor.opacity(0.2) : Color.clear)
                                    )
                            }
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Detail:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        ForEach([1, 5, 10], id: \.self) { sensitivity in
                            Button(action: { scrubSensitivity = sensitivity }) {
                                Text(sensitivity == 1 ? "Fine" : sensitivity == 5 ? "Med" : "Coarse")
                                    .font(.caption)
                                    .fontWeight(scrubSensitivity == sensitivity ? .bold : .regular)
                                    .foregroundColor(scrubSensitivity == sensitivity ? .accentColor : .secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(scrubSensitivity == sensitivity ? Color.accentColor.opacity(0.2) : Color.clear)
                                    )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    private func handleSwipeGesture(translation: CGFloat) {
        guard !routePoints.isEmpty else { return }
        
        let sensitivity = CGFloat(scrubSensitivity)
        let swipeThreshold: CGFloat = 50.0 / sensitivity
        
        if abs(translation) > swipeThreshold {
            if translation > 0 {
                stepBackward()
            } else {
                stepForward()
            }
        }
    }
    
    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func triggerMilestoneHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    private func startPlayback() {
        guard !routePoints.isEmpty else { return }
        
        if selectedPointIndex == nil || selectedPointIndex == routePoints.count - 1 {
            selectedPointIndex = 0
        }
        
        isPlaying = true
        let interval = 0.1 / playbackSpeed
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            guard let currentIndex = selectedPointIndex else {
                stopPlayback()
                return
            }
            
            if currentIndex < routePoints.count - 1 {
                let nextIndex = min(currentIndex + scrubSensitivity, routePoints.count - 1)
                selectedPointIndex = nextIndex
                
                if shouldPauseAtIndex(nextIndex) {
                    stopPlayback()
                    triggerMilestoneHaptic()
                }
            } else {
                stopPlayback()
                triggerMilestoneHaptic()
            }
        }
    }
    
    private func stopPlayback() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func stepForward() {
        guard let current = selectedPointIndex else { return }
        let next = min(current + scrubSensitivity, routePoints.count - 1)
        if next != current {
            selectedPointIndex = next
            if next == routePoints.count - 1 {
                triggerMilestoneHaptic()
            }
        }
    }
    
    private func stepBackward() {
        guard let current = selectedPointIndex else { return }
        let prev = max(current - scrubSensitivity, 0)
        if prev != current {
            selectedPointIndex = prev
            if prev == 0 {
                triggerMilestoneHaptic()
            }
        }
    }
    
    private func skipToStart() {
        selectedPointIndex = 0
        triggerMilestoneHaptic()
    }
    
    private func skipToEnd() {
        selectedPointIndex = routePoints.count - 1
        triggerMilestoneHaptic()
    }
    
    private func analyzeTrip() {
        guard !routePoints.isEmpty else { return }
        
        var events: [TripEvent] = []
        
        if let fastestIndex = routePoints.indices.max(by: { routePoints[$0].speed < routePoints[$1].speed }) {
            let fastestPoint = routePoints[fastestIndex]
            events.append(.fastestSpeed(index: fastestIndex, speed: fastestPoint.speed))
        }
        
        var currentStopStart: Int?
        var longestStopDuration: TimeInterval = 0
        var longestStopIndex: Int?
        
        for (index, point) in routePoints.enumerated() {
            if point.speedMPH < 2 {
                if currentStopStart == nil {
                    currentStopStart = index
                }
            } else {
                if let stopStart = currentStopStart, index > stopStart {
                    let duration = point.timestamp.timeIntervalSince(routePoints[stopStart].timestamp)
                    if duration > longestStopDuration && duration > 60 {
                        longestStopDuration = duration
                        longestStopIndex = stopStart
                    }
                }
                currentStopStart = nil
            }
        }
        
        if let stopIndex = longestStopIndex {
            events.append(.longestStop(index: stopIndex, duration: longestStopDuration))
        }
        
        for i in 1..<routePoints.count {
            let speedChange = abs(routePoints[i].speedMPH - routePoints[i-1].speedMPH)
            if speedChange > 20 {
                events.append(.significantSpeedChange(index: i, change: speedChange))
            }
        }
        
        tripEvents = events
    }
    
    private func jumpToEvent(_ event: TripEvent) {
        selectedPointIndex = event.index
        triggerMilestoneHaptic()
    }
    
    private func shouldPauseAtIndex(_ index: Int) -> Bool {
        return tripEvents.contains { $0.index == index }
    }
    
    private func shareCurrentMoment() {
        guard let point = selectedPoint else { return }
        
        shareContent = """
        Trip Moment
        Time: \(point.timestamp.formatted(date: .abbreviated, time: .shortened))
        Speed: \(formatSpeed(point.speed))
        Distance: \(formatDistance(point.distanceFromStart)) from start
        """
        
        exportedVideoURL = nil
        showShareSheet = true
        triggerMilestoneHaptic()
    }
    
    private func exportTripVideo() {
        guard !routePoints.isEmpty else { return }
        
        isExporting = true
        exportProgress = 0.0
        triggerMilestoneHaptic()
        
        Task {
            let videoURL = await createTripVideo()
            
            await MainActor.run {
                isExporting = false
                exportedVideoURL = videoURL
                showExportAlert = true
            }
        }
    }
    
    private func createTripVideo() async -> URL? {
        guard !routePoints.isEmpty else { return nil }
        
        let fileName = "trip_\(trip.startTime.formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-"))_\(UUID().uuidString.prefix(8)).mp4"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try? FileManager.default.removeItem(at: outputURL)
        
        let videoSize = CGSize(width: 1080, height: 1920)
        let fps: Int32 = 30
        
        // Create one frame per route point for complete accuracy
        let framesPerPoint = 2 // Show each coordinate for 2 frames (smoother motion)
        let totalFrames = routePoints.count * framesPerPoint
        
        // Calculate video duration based on total frames
        let videoDuration = Double(totalFrames) / Double(fps)
        
        print("Creating video: \(routePoints.count) points, \(totalFrames) frames, \(String(format: "%.1f", videoDuration)) seconds")
        
        // Generate map snapshots for EVERY route point for perfectly smooth animation
        var cachedSnapshots: [Int: UIImage] = [:]
        
        await MainActor.run {
            self.exportProgress = 0.05
        }
        
        // Process in batches to avoid memory issues
        let batchSize = 20
        let uniquePoints = Set(stride(from: 0, to: totalFrames, by: framesPerPoint).map { $0 })
        let pointFrames = Array(uniquePoints).sorted()
        
        print("Generating \(pointFrames.count) unique map snapshots...")
        
        for batchStart in stride(from: 0, to: pointFrames.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, pointFrames.count)
            let batch = Array(pointFrames[batchStart..<batchEnd])
            
            await withTaskGroup(of: (Int, UIImage?).self) { group in
                for frameIndex in batch {
                    group.addTask {
                        let pointIndex = frameIndex / framesPerPoint
                        let snapshot = await self.generateMapSnapshot(for: pointIndex, size: videoSize)
                        return (frameIndex, snapshot)
                    }
                }
                
                for await (frameIndex, snapshot) in group {
                    if let snapshot = snapshot {
                        cachedSnapshots[frameIndex] = snapshot
                    }
                }
            }
            
            let progress = 0.05 + (0.45 * Double(batchEnd) / Double(pointFrames.count))
            await MainActor.run {
                self.exportProgress = progress
            }
            
            // Optional: Small delay to prevent overwhelming the system
            if batchStart % 100 == 0 && batchStart > 0 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }
        
        await MainActor.run {
            self.exportProgress = 0.5
        }
        
        print("Snapshots generated, creating video file...")
        
        guard let videoWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            return nil
        }
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoSize.width,
            AVVideoHeightKey: videoSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6000000, // Higher bitrate for better quality
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: fps
            ]
        ]
        
        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoWriterInput.expectsMediaDataInRealTime = false
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoWriterInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: videoSize.width,
                kCVPixelBufferHeightKey as String: videoSize.height
            ]
        )
        
        videoWriter.add(videoWriterInput)
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)
        
        var frameCount = 0
        
        await withCheckedContinuation { continuation in
            videoWriterInput.requestMediaDataWhenReady(on: DispatchQueue(label: "videoWriterQueue")) {
                while videoWriterInput.isReadyForMoreMediaData && frameCount < totalFrames {
                    let presentationTime = CMTime(value: Int64(frameCount), timescale: fps)
                    
                    // Map frame to exact route point
                    let pointIndex = frameCount / framesPerPoint
                    
                    // Find the snapshot for this point (should exist for every point now)
                    let snapshotFrameIndex = (frameCount / framesPerPoint) * framesPerPoint
                    let cachedSnapshot = cachedSnapshots[snapshotFrameIndex]
                    
                    if let pixelBuffer = self.createVideoFrameFast(
                        size: videoSize,
                        pointIndex: pointIndex,
                        totalPoints: self.routePoints.count,
                        cachedMapSnapshot: cachedSnapshot
                    ) {
                        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                    }
                    
                    frameCount += 1
                    
                    // Update progress more frequently
                    if frameCount % 20 == 0 {
                        let progress = 0.5 + (0.5 * Double(frameCount) / Double(totalFrames))
                        Task { @MainActor in
                            self.exportProgress = progress
                        }
                    }
                }
                
                if frameCount >= totalFrames {
                    videoWriterInput.markAsFinished()
                    videoWriter.finishWriting {
                        print("Video export complete!")
                        continuation.resume()
                    }
                }
            }
        }
        
        guard videoWriter.status == .completed else {
            print("Video export failed with status: \(videoWriter.status.rawValue)")
            return nil
        }
        
        return outputURL
    }
    
    private func generateMapSnapshot(for pointIndex: Int, size: CGSize) async -> UIImage? {
        let point = routePoints[pointIndex]
        let mapRect = CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.7)
        
        let mapSnapshotOptions = MKMapSnapshotter.Options()
        let regionRadius: CLLocationDistance = 1500
        
        mapSnapshotOptions.region = MKCoordinateRegion(
            center: point.coordinate,
            latitudinalMeters: regionRadius * 2,
            longitudinalMeters: regionRadius * 2
        )
        mapSnapshotOptions.size = mapRect.size
        mapSnapshotOptions.scale = 2.0
        
        return await withCheckedContinuation { continuation in
            let snapshotter = MKMapSnapshotter(options: mapSnapshotOptions)
            snapshotter.start { snapshot, error in
                guard let snapshot = snapshot else {
                    continuation.resume(returning: nil)
                    return
                }
                
                UIGraphicsBeginImageContextWithOptions(mapRect.size, true, 2.0)
                defer { UIGraphicsEndImageContext() }
                
                guard let context = UIGraphicsGetCurrentContext() else {
                    continuation.resume(returning: nil)
                    return
                }
                
                snapshot.image.draw(at: .zero)
                
                context.setLineWidth(8)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                
                context.setStrokeColor(UIColor.systemGray.withAlphaComponent(0.4).cgColor)
                if let firstPoint = self.routePoints.first {
                    let startPt = snapshot.point(for: firstPoint.coordinate)
                    context.move(to: startPt)
                    
                    for routePoint in self.routePoints.dropFirst() {
                        let pt = snapshot.point(for: routePoint.coordinate)
                        context.addLine(to: pt)
                    }
                    context.strokePath()
                }
                
                if pointIndex > 0 {
                    context.setStrokeColor(UIColor.systemBlue.cgColor)
                    context.setLineWidth(10)
                    
                    let firstPoint = snapshot.point(for: self.routePoints[0].coordinate)
                    context.move(to: firstPoint)
                    
                    for i in 1...min(pointIndex, self.routePoints.count - 1) {
                        let pt = snapshot.point(for: self.routePoints[i].coordinate)
                        context.addLine(to: pt)
                    }
                    context.strokePath()
                }
                
                let currentPoint = snapshot.point(for: point.coordinate)
                
                context.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.3).cgColor)
                
                context.setFillColor(UIColor.white.cgColor)
                context.fillEllipse(in: CGRect(x: currentPoint.x - 18, y: currentPoint.y - 18, width: 36, height: 36))
                
                context.setShadow(offset: .zero, blur: 0, color: nil)
                
                context.setFillColor(UIColor.systemBlue.cgColor)
                context.fillEllipse(in: CGRect(x: currentPoint.x - 14, y: currentPoint.y - 14, width: 28, height: 28))
                
                context.setFillColor(UIColor.white.cgColor)
                context.fillEllipse(in: CGRect(x: currentPoint.x - 6, y: currentPoint.y - 6, width: 12, height: 12))
                
                let finalImage = UIGraphicsGetImageFromCurrentImageContext()
                continuation.resume(returning: finalImage)
            }
        }
    }
    
    private func createVideoFrameFast(size: CGSize, pointIndex: Int, totalPoints: Int, cachedMapSnapshot: UIImage?) -> CVPixelBuffer? {
        let point = routePoints[pointIndex]
        
        var pixelBuffer: CVPixelBuffer?
        let options: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            options as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            return nil
        }
        
        // Fill background
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        let mapRect = CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.7)
        
        // Draw map
        if let snapshot = cachedMapSnapshot, let cgImage = snapshot.cgImage {
            context.draw(cgImage, in: mapRect)
        } else {
            drawSimpleRouteMap(context: context, point: point, pointIndex: pointIndex, mapRect: mapRect)
        }
        
        // CRITICAL: Draw overlays on every frame
        drawOverlays(context: context, point: point, pointIndex: pointIndex, totalPoints: totalPoints, size: size)
        
        return buffer
    }
    
    private func drawSimpleRouteMap(context: CGContext, point: RoutePoint, pointIndex: Int, mapRect: CGRect) {
        context.setFillColor(UIColor.systemGray6.cgColor)
        context.fill(mapRect)
        
        let padding: CGFloat = 100
        let drawableRect = mapRect.insetBy(dx: padding, dy: padding)
        
        guard !routePoints.isEmpty else { return }
        
        let minLat = routePoints.map { $0.coordinate.latitude }.min() ?? 0
        let maxLat = routePoints.map { $0.coordinate.latitude }.max() ?? 0
        let minLon = routePoints.map { $0.coordinate.longitude }.min() ?? 0
        let maxLon = routePoints.map { $0.coordinate.longitude }.max() ?? 0
        
        let latRange = max(maxLat - minLat, 0.001)
        let lonRange = max(maxLon - minLon, 0.001)
        
        func pointForCoordinate(_ coord: CLLocationCoordinate2D) -> CGPoint {
            let x = drawableRect.origin.x + ((coord.longitude - minLon) / lonRange) * drawableRect.width
            let y = drawableRect.origin.y + drawableRect.height - ((coord.latitude - minLat) / latRange) * drawableRect.height
            return CGPoint(x: x, y: y)
        }
        
        // Draw traveled route (blue)
        if pointIndex > 0 {
            context.setStrokeColor(UIColor.systemBlue.cgColor)
            context.setLineWidth(8)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            let firstPoint = pointForCoordinate(routePoints[0].coordinate)
            context.move(to: firstPoint)
            
            for i in 1...pointIndex {
                let pt = pointForCoordinate(routePoints[i].coordinate)
                context.addLine(to: pt)
            }
            context.strokePath()
        }
        
        // Draw remaining route (gray)
        if pointIndex < routePoints.count - 1 {
            context.setStrokeColor(UIColor.systemGray3.cgColor)
            context.setLineWidth(6)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            let currentPt = pointForCoordinate(routePoints[pointIndex].coordinate)
            context.move(to: currentPt)
            
            for i in (pointIndex + 1)..<routePoints.count {
                let pt = pointForCoordinate(routePoints[i].coordinate)
                context.addLine(to: pt)
            }
            context.strokePath()
        }
        
        // Draw start point marker (green)
        let startPoint = pointForCoordinate(routePoints[0].coordinate)
        context.setFillColor(UIColor.systemGreen.cgColor)
        context.fillEllipse(in: CGRect(x: startPoint.x - 15, y: startPoint.y - 15, width: 30, height: 30))
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: startPoint.x - 8, y: startPoint.y - 8, width: 16, height: 16))
        
        // Draw end point marker (red)
        let endPoint = pointForCoordinate(routePoints[routePoints.count - 1].coordinate)
        context.setFillColor(UIColor.systemRed.cgColor)
        context.fillEllipse(in: CGRect(x: endPoint.x - 15, y: endPoint.y - 15, width: 30, height: 30))
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: endPoint.x - 8, y: endPoint.y - 8, width: 16, height: 16))
        
        // Draw current position marker
        let currentPoint = pointForCoordinate(point.coordinate)
        
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: currentPoint.x - 20, y: currentPoint.y - 20, width: 40, height: 40))
        
        context.setFillColor(UIColor.systemBlue.cgColor)
        context.fillEllipse(in: CGRect(x: currentPoint.x - 14, y: currentPoint.y - 14, width: 28, height: 28))
        
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: currentPoint.x - 6, y: currentPoint.y - 6, width: 12, height: 12))
    }
    
    private func drawOverlays(context: CGContext, point: RoutePoint, pointIndex: Int, totalPoints: Int, size: CGSize) {
        let overlayY = size.height * 0.7
        let overlayHeight = size.height * 0.3
        
        // Draw semi-transparent background
        context.setFillColor(UIColor.black.withAlphaComponent(0.8).cgColor)
        context.fill(CGRect(x: 0, y: overlayY, width: size.width, height: overlayHeight))
        
        // Use NSString drawing which works in normal coordinate system
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .medium),
            .foregroundColor: UIColor.lightGray
        ]
        
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 56, weight: .heavy),
            .foregroundColor: UIColor.white
        ]
        
        let smallValueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 44, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        
        // Create an image context for text rendering
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size.width, height: overlayHeight), false, 1.0)
        guard let textContext = UIGraphicsGetCurrentContext() else { return }
        
        // Speed (left side)
        let speedLabel = "SPEED" as NSString
        let speedValue = formatSpeed(point.speed) as NSString
        
        speedLabel.draw(at: CGPoint(x: 80, y: 50), withAttributes: labelAttributes)
        speedValue.draw(at: CGPoint(x: 80, y: 90), withAttributes: valueAttributes)
        
        // Time (center)
        let timeLabel = "TIME" as NSString
        let timeValue = point.timestamp.formatted(date: .omitted, time: .shortened) as NSString
        
        let centerX = size.width / 2
        let timeLabelSize = timeLabel.size(withAttributes: labelAttributes)
        let timeValueSize = timeValue.size(withAttributes: smallValueAttributes)
        
        timeLabel.draw(at: CGPoint(x: centerX - timeLabelSize.width / 2, y: 50), withAttributes: labelAttributes)
        timeValue.draw(at: CGPoint(x: centerX - timeValueSize.width / 2, y: 90), withAttributes: smallValueAttributes)
        
        // Distance (right side)
        let distanceLabel = "DISTANCE" as NSString
        let distanceValue = formatDistance(point.distanceFromStart) as NSString
        
        let distanceLabelSize = distanceLabel.size(withAttributes: labelAttributes)
        let distanceValueSize = distanceValue.size(withAttributes: smallValueAttributes)
        
        distanceLabel.draw(at: CGPoint(x: size.width - 80 - distanceLabelSize.width, y: 50), withAttributes: labelAttributes)
        distanceValue.draw(at: CGPoint(x: size.width - 80 - distanceValueSize.width, y: 90), withAttributes: smallValueAttributes)
        
        // Get the rendered text as an image
        let textImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Draw the text image onto the main context
        if let textImage = textImage, let cgImage = textImage.cgImage {
            context.draw(cgImage, in: CGRect(x: 0, y: overlayY, width: size.width, height: overlayHeight))
        }
        
        // Progress bar
        let progressBarY = overlayY + 240
        let progressBarWidth = size.width - 160
        let progressBarHeight: CGFloat = 16
        
        // Background
        context.setFillColor(UIColor.darkGray.cgColor)
        let progressBarRect = CGRect(x: 80, y: progressBarY, width: progressBarWidth, height: progressBarHeight)
        let progressBarPath = UIBezierPath(roundedRect: progressBarRect, cornerRadius: progressBarHeight / 2)
        context.addPath(progressBarPath.cgPath)
        context.fillPath()
        
        // Progress fill
        let progress = CGFloat(pointIndex) / CGFloat(max(totalPoints - 1, 1))
        context.setFillColor(UIColor.systemBlue.cgColor)
        let filledRect = CGRect(x: 80, y: progressBarY, width: progressBarWidth * progress, height: progressBarHeight)
        let filledPath = UIBezierPath(roundedRect: filledRect, cornerRadius: progressBarHeight / 2)
        context.addPath(filledPath.cgPath)
        context.fillPath()
        
        // Progress percentage text
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 200, height: 60), false, 1.0)
        
        let progressText = "\(Int(progress * 100))%" as NSString
        let progressAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 36, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let progressTextSize = progressText.size(withAttributes: progressAttributes)
        progressText.draw(at: CGPoint(x: 0, y: 0), withAttributes: progressAttributes)
        
        let progressTextImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if let progressTextImage = progressTextImage, let cgImage = progressTextImage.cgImage {
            context.draw(cgImage, in: CGRect(x: size.width / 2 - progressTextSize.width / 2, y: progressBarY + 30, width: progressTextSize.width, height: 40))
        }
    }
    
    private func drawText(context: CGContext, text: String, x: CGFloat, y: CGFloat, fontSize: CGFloat, color: UIColor) {
        // This function is no longer needed but kept for compatibility
    }
    
    private func saveVideoToFiles(url: URL) {
        let documentPicker = UIDocumentPickerViewController(forExporting: [url])
        documentPicker.shouldShowFileExtensions = true
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(documentPicker, animated: true)
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
    
    private func generateRoutePoints() {
        guard !trip.routeCoordinates.isEmpty else { return }
        
        let coordinates = trip.routeCoordinates.map { $0.clCoordinate }
        let totalDuration = trip.endTime.timeIntervalSince(trip.startTime)
        
        var points: [RoutePoint] = []
        var cumulativeDistance: Double = 0
        
        for (index, coord) in coordinates.enumerated() {
            let progress = Double(index) / Double(max(coordinates.count - 1, 1))
            let timestamp = trip.startTime.addingTimeInterval(totalDuration * progress)
            
            var speed: Double = 0
            if index < coordinates.count - 1 {
                let currentLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                let nextCoord = coordinates[index + 1]
                let nextLocation = CLLocation(latitude: nextCoord.latitude, longitude: nextCoord.longitude)
                
                let distance = currentLocation.distance(from: nextLocation)
                let timeDelta = totalDuration / Double(coordinates.count - 1)
                speed = timeDelta > 0 ? distance / timeDelta : 0
                
                cumulativeDistance += distance / 1609.34
            } else if let lastSpeed = points.last?.speed {
                speed = lastSpeed
            }
            
            let point = RoutePoint(
                coordinate: coord,
                timestamp: timestamp,
                speed: speed,
                distanceFromStart: cumulativeDistance
            )
            points.append(point)
        }
        
        routePoints = points
        
        if !points.isEmpty {
            selectedPointIndex = 0
        }
    }
    
    private func formatSpeed(_ speedMS: Double) -> String {
        if useKilometers {
            return String(format: "%.0f km/h", speedMS * 3.6)
        } else {
            return String(format: "%.0f mph", speedMS * 2.23694)
        }
    }
    
    private func formatDistance(_ miles: Double) -> String {
        if useKilometers {
            return String(format: "%.2f km", miles * 1.60934)
        } else {
            return String(format: "%.2f mi", miles)
        }
    }
    
    private func speedColor(_ speedMPH: Double) -> Color {
        if speedMPH < 25 {
            return .green
        } else if speedMPH < 55 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Scrubbable Map View
struct ScrubbableMapView: UIViewRepresentable {
    let trip: Trip
    let routePoints: [RoutePoint]
    @Binding var selectedPointIndex: Int?
    @Binding var hasInitiallyFitRoute: Bool
    let rotateWithDirection: Bool
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        let coordinates = trip.routeCoordinates.map { $0.clCoordinate }
        guard !coordinates.isEmpty else { return }
        
        addColoredRouteSegments(to: mapView, coordinates: coordinates)
        
        if let selectedIndex = selectedPointIndex, selectedIndex > 0 {
            let traveledCoords = Array(coordinates[0...selectedIndex])
            let traveledPolyline = MKPolyline(coordinates: traveledCoords, count: traveledCoords.count)
            context.coordinator.traveledPolyline = traveledPolyline
            mapView.addOverlay(traveledPolyline, level: .aboveLabels)
        }
        
        if let selectedIndex = selectedPointIndex,
           selectedIndex < routePoints.count {
            let point = routePoints[selectedIndex]
            let annotation = MKPointAnnotation()
            annotation.coordinate = point.coordinate
            annotation.title = "Current Position"
            mapView.addAnnotation(annotation)
            
            var heading: CLLocationDirection = 0
            if rotateWithDirection && selectedIndex < routePoints.count - 1 {
                let currentCoord = point.coordinate
                let nextCoord = routePoints[selectedIndex + 1].coordinate
                
                let dy = nextCoord.latitude - currentCoord.latitude
                let dx = nextCoord.longitude - currentCoord.longitude
                heading = (atan2(dx, dy) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
            }
            
            if !hasInitiallyFitRoute {
                let region = MKCoordinateRegion(
                    center: point.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                mapView.setRegion(region, animated: false)
                hasInitiallyFitRoute = true
            } else {
                let camera = MKMapCamera(
                    lookingAtCenter: point.coordinate,
                    fromDistance: mapView.camera.centerCoordinateDistance,
                    pitch: 0,
                    heading: heading
                )
                mapView.setCamera(camera, animated: true)
            }
        }
    }
    
    private func addColoredRouteSegments(to mapView: MKMapView, coordinates: [CLLocationCoordinate2D]) {
        guard routePoints.count > 1 else { return }
        
        for i in 0..<routePoints.count - 1 {
            let segment = [routePoints[i].coordinate, routePoints[i + 1].coordinate]
            let polyline = ColoredPolyline(coordinates: segment, count: 2)
            polyline.color = speedColor(routePoints[i].speedMPH)
            mapView.addOverlay(polyline, level: .aboveRoads)
        }
    }
    
    private func speedColor(_ speedMPH: Double) -> UIColor {
        if speedMPH < 25 {
            return .systemGreen
        } else if speedMPH < 55 {
            return .systemOrange
        } else {
            return .systemRed
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var traveledPolyline: MKPolyline?
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            
            let renderer = MKPolylineRenderer(polyline: polyline)
            
            if overlay === traveledPolyline {
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 6
            } else if let coloredPolyline = overlay as? ColoredPolyline {
                renderer.strokeColor = coloredPolyline.color
                renderer.lineWidth = 4
            } else {
                renderer.strokeColor = .systemGray3
                renderer.lineWidth = 4
            }
            
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "CurrentPosition"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
            } else {
                annotationView?.annotation = annotation
            }
            
            annotationView?.markerTintColor = .systemBlue
            annotationView?.glyphImage = UIImage(systemName: "location.fill")
            
            return annotationView
        }
    }
}

// MARK: - Colored Polyline
class ColoredPolyline: MKPolyline {
    var color: UIColor = .systemBlue
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
