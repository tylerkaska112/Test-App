import SwiftUI
import MapKit
import UniformTypeIdentifiers
import AVFoundation
import LocalAuthentication

// MARK: - Enums

enum DateRange: String, CaseIterable, Identifiable {
    case all = "All Time"
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case last3Months = "Last 3 Months"
    case last6Months = "Last 6 Months"
    case thisYear = "This Year"
    
    var id: String { rawValue }
    
    var dateRange: (start: Date, end: Date)? {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .all:
            return nil
        case .today:
            return (calendar.startOfDay(for: now), now)
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (startOfWeek, now)
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return (startOfMonth, now)
        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let startOfLastMonth = calendar.dateInterval(of: .month, for: lastMonth)?.start ?? now
            let endOfLastMonth = calendar.dateInterval(of: .month, for: lastMonth)?.end ?? now
            return (startOfLastMonth, endOfLastMonth)
        case .last3Months:
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return (threeMonthsAgo, now)
        case .last6Months:
            let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            return (sixMonthsAgo, now)
        case .thisYear:
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            return (startOfYear, now)
        }
    }
}

enum SortOption: String, CaseIterable, Identifiable {
    case dateDescending = "Date (Newest)"
    case dateAscending = "Date (Oldest)"
    case distanceDescending = "Distance (Longest)"
    case distanceAscending = "Distance (Shortest)"
    case timeDescending = "Time (Longest)"
    case timeAscending = "Time (Shortest)"
    var id: String { rawValue }
}

enum ExportFormat {
    case csv, json
}

enum TripExportError: LocalizedError {
    case encodingFailed
    case fileWriteFailed(Error)
    case invalidData
    case noTripsSelected
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode trip data"
        case .fileWriteFailed(let error):
            return "File write error: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid trip data"
        case .noTripsSelected:
            return "No trips selected for export"
        }
    }
}

// MARK: - SelectedImage Wrapper

struct SelectedImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

fileprivate struct TripExport: Codable {
    let id: UUID
    let date: Date
    let distance: Double
    let notes: String
    let pay: String
    let audioNotes: [URL]
    let photoURLs: [URL]
    let startCoordinate: CodableCoordinate?
    let endCoordinate: CodableCoordinate?
    let routeCoordinates: [CodableCoordinate]
    let startTime: Date
    let endTime: Date
    let reason: String
    let isRecovered: Bool
    let averageSpeed: Double?
    
    init(trip: Trip) {
        self.id = trip.id
        self.date = trip.date
        self.distance = trip.distance
        self.notes = trip.notes
        self.pay = trip.pay
        self.audioNotes = trip.audioNotes
        self.photoURLs = trip.photoURLs
        self.startCoordinate = trip.startCoordinate
        self.endCoordinate = trip.endCoordinate
        self.routeCoordinates = trip.routeCoordinates
        self.startTime = trip.startTime
        self.endTime = trip.endTime
        self.reason = trip.reason
        self.isRecovered = trip.isRecovered
        self.averageSpeed = trip.averageSpeed
    }
}

// MARK: - Helper

struct AverageSpeedFormatter {
    static func string(forMetersPerSecond speed: Double, useKilometers: Bool) -> String {
        if useKilometers {
            let kmh = speed * 3.6
            return String(format: "%.1f km/h", kmh)
        } else {
            let mph = speed * 2.23694
            return String(format: "%.1f mph", mph)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var activityItems: [Any] { items }
    
    init(items: [Any]) {
        self.items = items
    }
    
    init(activityItems: [Any]) {
        self.items = activityItems
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

// MARK: - View Model

@MainActor
class TripLogViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var sortOption: SortOption = .dateDescending
    @Published var dateRangeFilter: DateRange = .all
    @Published var minDistanceFilter: Double = 0
    @Published var maxDistanceFilter: Double = 1000
    @Published var selectedReasonFilter: String = "All"
    @Published var selectedTripIDs: Set<UUID> = []
    
    private var cachedFilteredTrips: [Trip] = []
    
    private var lastSearchText: String = ""
    private var lastSortOption: SortOption = .dateDescending
    private var lastDateRange: DateRange = .all
    private var lastReasonFilter: String = "All"
    private var lastMinDistance: Double = 0
    private var lastMaxDistance: Double = 1000
    private var lastTripCount: Int = 0
    private var searchTask: Task<Void, Never>?
    
    func updateSearch(_ newValue: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    self.searchText = newValue
                    self.invalidateCache()
                }
            }
        }
    }
    
    func invalidateCache() {
        cachedFilteredTrips = []
        lastSearchText = ""
        lastSortOption = .dateDescending
        lastDateRange = .all
        lastReasonFilter = "All"
        lastMinDistance = 0
        lastMaxDistance = 1000
        lastTripCount = 0
    }
    
    func filteredTrips(from trips: [Trip]) -> [Trip] {
        let needsRecalculation = cachedFilteredTrips.isEmpty ||
            searchText != lastSearchText ||
            sortOption != lastSortOption ||
            dateRangeFilter != lastDateRange ||
            selectedReasonFilter != lastReasonFilter ||
            minDistanceFilter != lastMinDistance ||
            maxDistanceFilter != lastMaxDistance ||
            trips.count != lastTripCount
        
        if needsRecalculation {
            let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            var results = sortedTrips(from: trips)
            
            if !trimmedSearch.isEmpty {
                results = results.filter {
                    $0.notes.localizedCaseInsensitiveContains(trimmedSearch) ||
                    $0.reason.localizedCaseInsensitiveContains(trimmedSearch)
                }
            }
            
            if let range = dateRangeFilter.dateRange {
                results = results.filter { trip in
                    trip.startTime >= range.start && trip.startTime <= range.end
                }
            }
            
            if selectedReasonFilter != "All" {
                results = results.filter { $0.reason == selectedReasonFilter }
            }
            
            if minDistanceFilter > 0 || maxDistanceFilter < 1000 {
                results = results.filter { trip in
                    let distanceKm = trip.distance / 1000
                    return distanceKm >= minDistanceFilter && distanceKm <= maxDistanceFilter
                }
            }
            
            cachedFilteredTrips = results
            lastSearchText = searchText
            lastSortOption = sortOption
            lastDateRange = dateRangeFilter
            lastReasonFilter = selectedReasonFilter
            lastMinDistance = minDistanceFilter
            lastMaxDistance = maxDistanceFilter
            lastTripCount = trips.count
        }
        
        return cachedFilteredTrips
    }
    
    func sortedTrips(from trips: [Trip]) -> [Trip] {
        switch sortOption {
        case .dateDescending:
            return trips.sorted { $0.startTime > $1.startTime }
        case .dateAscending:
            return trips.sorted { $0.startTime < $1.startTime }
        case .distanceDescending:
            return trips.sorted { $0.distance > $1.distance }
        case .distanceAscending:
            return trips.sorted { $0.distance < $1.distance }
        case .timeDescending:
            return trips.sorted {
                $0.endTime.timeIntervalSince($0.startTime) > $1.endTime.timeIntervalSince($1.startTime)
            }
        case .timeAscending:
            return trips.sorted {
                $0.endTime.timeIntervalSince($0.startTime) < $1.endTime.timeIntervalSince($1.startTime)
            }
        }
    }
    
    func resetFilters() {
        dateRangeFilter = .all
        selectedReasonFilter = "All"
        minDistanceFilter = 0
        maxDistanceFilter = 1000
        searchText = ""
        invalidateCache()
    }
}

// MARK: - Main View

struct TripLogView: View {
    @State private var navigationStackActive = false
    @State private var selectedTrip: Trip? = nil
    
    @EnvironmentObject var tripManager: TripManager
    @StateObject private var viewModel = TripLogViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.undoManager) var undoManager
    
    @State private var expandedTripID: UUID? = nil
    @State private var editingTrip: Trip? = nil
    @State private var showShareSheet = false
    @State private var exportURL: URL? = nil
    @AppStorage("useKilometers") private var useKilometers: Bool = false
    
    @AppStorage("tripLogProtectionEnabled") private var tripLogProtectionEnabled: Bool = false
    @AppStorage("tripLogProtectionMethod") private var tripLogProtectionMethod: String = "biometric"
    
    @State private var isAuthenticated = false
    @State private var showAuthError = false
    @State private var authErrorMessage = ""
    
    @State private var audioPlayer: AVAudioPlayer? = nil
    @State private var showAudioErrorAlert = false
    @State private var audioErrorMessage = ""
    
    @State private var selectedFullImage: SelectedImage? = nil
    
    @AppStorage("recentSearches") private var recentSearchesData: Data = Data()
    
    @State private var showCopyToast = false
    @State private var copyFormat: String = "CSV"
    @State private var showStatistics = false
    @State private var showAdvancedFilters = false
    
    @State private var didAttemptInitialAuth = false
    
    @State private var showDeleteConfirmation = false
    @State private var showPremiumUpgradePrompt = false
    @State private var showExportError = false
    @State private var exportError: TripExportError?
    @State private var showBulkEditSheet = false
    @State private var showImportSheet = false
    
    // MARK: - Computed Properties
    
    var recentSearches: [String] {
        (try? JSONDecoder().decode([String].self, from: recentSearchesData)) ?? []
    }
    
    var availableReasons: [String] {
        let reasons = Set(tripManager.trips.map { $0.reason }.filter { !$0.isEmpty })
        return ["All"] + Array(reasons).sorted()
    }
    
    var filteredTrips: [Trip] {
        viewModel.filteredTrips(from: tripManager.trips)
    }
    
    var selectedTrips: [Trip] {
        tripManager.trips.filter { viewModel.selectedTripIDs.contains($0.id) }
    }
    
    var totalStats: (distance: Double, duration: TimeInterval, earnings: Double, count: Int) {
        let trips = filteredTrips
        let totalDistance = trips.reduce(0) { $0 + $1.distance }
        let totalDuration = trips.reduce(0) { $0 + $1.endTime.timeIntervalSince($1.startTime) }
        let totalEarnings = trips.compactMap { Double($0.pay) }.reduce(0, +)
        return (totalDistance, totalDuration, totalEarnings, trips.count)
    }

    var extendedStats: (avgSpeed: Double, topCategory: String, costPerDistance: Double) {
        let trips = filteredTrips
        
        let speeds = trips.compactMap { $0.averageSpeed }
        let avgSpeed = speeds.isEmpty ? 0 : speeds.reduce(0, +) / Double(speeds.count)
        
        let categoryCounts = Dictionary(grouping: trips, by: { $0.reason })
            .mapValues { $0.count }
        let topCategory = categoryCounts.max(by: { $0.value < $1.value })?.key ?? "None"
        
        let totalDistance = totalStats.distance
        let costPerDistance = totalDistance > 0 ? totalStats.earnings / totalDistance : 0
        
        return (avgSpeed, topCategory, costPerDistance)
    }

    // MARK: - Helper Functions (FIXED)

    private func formatDistance(_ miles: Double) -> String {
        if useKilometers {
            return String(format: "%.2f km", miles * 1.60934)
        } else {
            return String(format: "%.2f mi", miles)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    // MARK: - Statistics Summary Section (FIXED)

    private var statisticsSummarySection: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    showStatistics.toggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Trip Summary")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 20) {
                            StatBox(
                                value: "\(totalStats.count)",
                                label: "Trips",
                                color: .accentColor,
                                icon: "car.fill"
                            )
                            
                            StatBox(
                                value: formatDistance(totalStats.distance),
                                label: "Distance",
                                color: .blue,
                                icon: "road.lanes"
                            )
                            
                            if totalStats.earnings > 0 {
                                StatBox(
                                    value: String(format: "$%.0f", totalStats.earnings),
                                    label: "Earnings",
                                    color: .green,
                                    icon: "dollarsign.circle.fill"
                                )
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: showStatistics ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .foregroundColor(.accentColor)
                        .font(.title2)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding()
            .background(.regularMaterial)
            
            if showStatistics {
                extendedStatsView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var extendedStatsView: some View {
        VStack(spacing: 16) {
            Divider()
            
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Avg Distance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    let avgDistance = totalStats.count > 0 ? totalStats.distance / Double(totalStats.count) : 0
                    Text(formatDistance(avgDistance))
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 30)
                
                VStack(spacing: 4) {
                    Text("Avg Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    let avgDuration = totalStats.count > 0 ? totalStats.duration / Double(totalStats.count) : 0
                    Text(formatDuration(avgDuration))
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                
                if totalStats.earnings > 0 {
                    Divider()
                        .frame(height: 30)
                    
                    VStack(spacing: 4) {
                        Text("Avg Earnings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        let avgEarnings = totalStats.count > 0 ? totalStats.earnings / Double(totalStats.count) : 0
                        Text(String(format: "$%.2f", avgEarnings))
                            .font(.subheadline.bold())
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Avg Speed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(AverageSpeedFormatter.string(forMetersPerSecond: extendedStats.avgSpeed, useKilometers: useKilometers))
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 30)
                
                VStack(spacing: 4) {
                    Text("Top Category")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(extendedStats.topCategory)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                
                if totalStats.earnings > 0 {
                    Divider()
                        .frame(height: 30)
                    
                    VStack(spacing: 4) {
                        Text(useKilometers ? "Per km" : "Per mi")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        let perDistance = useKilometers ? extendedStats.costPerDistance / 1.60934 : extendedStats.costPerDistance
                        Text(String(format: "$%.2f", perDistance))
                            .font(.subheadline.bold())
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Total Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDuration(totalStats.duration))
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 30)
                
                VStack(spacing: 4) {
                    Text("Total Distance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDistance(totalStats.distance))
                        .font(.subheadline.bold())
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                
                if totalStats.earnings > 0 {
                    Divider()
                        .frame(height: 30)
                    
                    VStack(spacing: 4) {
                        Text("Total Earnings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "$%.2f", totalStats.earnings))
                            .font(.subheadline.bold())
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.5))
    }
    
    // MARK: - Body
    
    var body: some View {
        if tripLogProtectionEnabled && !isAuthenticated {
            lockedView
        } else {
            mainContentView
        }
    }
    
    // MARK: - View Components
    
    private var lockedView: some View {
        VStack {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(.accentColor)
                .padding(.bottom, 20)
                .accessibilityLabel("Trip log locked")
            
            Text("Trip Log Locked")
                .font(.title)
            
            Text("Authenticate to view your trip logs.")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.bottom)
            
            Button("Authenticate") {
                authenticate()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Unlock trip logs using biometric authentication")
            
            if showAuthError {
                Text(authErrorMessage)
                    .foregroundColor(.red)
                    .padding(.top)
                    .accessibilityLabel("Authentication error: \(authErrorMessage)")
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thickMaterial)
        .ignoresSafeArea()
        .onAppear {
            if tripLogProtectionEnabled && !isAuthenticated && !didAttemptInitialAuth {
                didAttemptInitialAuth = true
                authenticate()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if tripLogProtectionEnabled && isAuthenticated && (newPhase == .background || newPhase == .inactive) {
                isAuthenticated = false
                didAttemptInitialAuth = false
                print("[TripLogView] App moved to background/inactive, relocking the view.")
            }
        }
    }
    
    private var mainContentView: some View {
        BackgroundWrapper {
            VStack(spacing: 0) {
                searchBarSection
                
                if !viewModel.searchText.isEmpty || !recentSearches.isEmpty {
                    recentSearchesSection
                }
                
                if showAdvancedFilters {
                    advancedFiltersSection
                }
                
                if !filteredTrips.isEmpty {
                    statisticsSummarySection
                }
                
                tripListSection
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button(action: { showAdvancedFilters.toggle() }) {
                        Label("Filters", systemImage: showAdvancedFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Toggle advanced filters")
                }
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button("View Statistics", systemImage: "chart.bar") {
                            showStatistics.toggle()
                        }
                        
                        Button("Import Trips", systemImage: "square.and.arrow.down") {
                            showImportSheet = true
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                    
                    Menu {
                        Button("Export as CSV", systemImage: "doc.text") {
                                exportTrips(format: .csv)
                            }
                        
                        
                        Button("Export as JSON", systemImage: "curlybraces") {
                                exportTrips(format: .json)
                            }
                        
                        
                        Divider()
                        
                        Button("Copy CSV", systemImage: "doc.on.doc") {
                                copyToClipboard(format: .csv)
                            }
                        
                        
                        Button("Copy JSON", systemImage: "chevron.left.slash.chevron.right") {
                                copyToClipboard(format: .json)
                            }
                        
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(viewModel.selectedTripIDs.isEmpty)
                }
}
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .sheet(item: $editingTrip) { trip in
                TripEditView(trip: trip) { updatedTrip in
                    tripManager.updateTrip(updatedTrip)
                    viewModel.invalidateCache()
                }
            }
            .sheet(isPresented: $showBulkEditSheet) {
                BulkEditView(trips: selectedTrips) { updatedTrips in
                    updatedTrips.forEach { tripManager.updateTrip($0) }
                    viewModel.invalidateCache()
                }
            }
            .sheet(isPresented: $showImportSheet) {
                ImportTripsView { importedTrips in
                    importedTrips.forEach { tripManager.trips.append($0) }
                    viewModel.invalidateCache()
                }
            }
            .alert("Audio Playback Error", isPresented: $showAudioErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(audioErrorMessage)
            }
            .alert("Export Error", isPresented: $showExportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(exportError?.localizedDescription ?? "An unknown error occurred")
            }
            .sheet(item: $selectedFullImage) { selected in
                ImageDetailView(image: selected.image) {
                    selectedFullImage = nil
                }
            }
            .alert("Delete Selected Logs?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { deleteSelectedTrips() }
            } message: {
                Text("This action is permanent and cannot be undone. Are you sure you want to delete \(viewModel.selectedTripIDs.count) trip(s)?")
            }
            .alert("Upgrade to Premium", isPresented: $showPremiumUpgradePrompt) {
                Button("Maybe Later", role: .cancel) {}
                Button("Upgrade") {
                }
            } message: {
                Text("Export features are available with Premium. Upgrade now to unlock advanced export options.")
            }
            .overlay(alignment: .bottom) {
                if !viewModel.selectedTripIDs.isEmpty {
                    VStack(spacing: 0) {
                        Divider()
                        
                        HStack(spacing: 16) {
                            Button(action: { toggleSelectAll() }) {
                                Text(viewModel.selectedTripIDs.count == filteredTrips.count ? "Deselect All" : "Select All")
                                    .font(.subheadline.bold())
                            }
                            .disabled(filteredTrips.isEmpty)
                            
                            Spacer()
                            
                            Text("\(viewModel.selectedTripIDs.count) selected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: { showBulkEditSheet = true }) {
                                Label("Edit", systemImage: "pencil.circle")
                                    .font(.subheadline.bold())
                            }
                            
                            Button(action: { showDeleteConfirmation = true }) {
                                Label("Delete", systemImage: "trash")
                                    .font(.subheadline.bold())
                            }
                            .foregroundColor(.red)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(.regularMaterial)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3), value: viewModel.selectedTripIDs.isEmpty)
                }
            }
            .overlay(toastOverlay)
            .onAppear {
                if tripLogProtectionEnabled && !isAuthenticated {
                    authenticate()
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if tripLogProtectionEnabled && isAuthenticated && (newPhase == .background || newPhase == .inactive) {
                    isAuthenticated = false
                    didAttemptInitialAuth = false
                    stopAudioPlayer()
                }
            }
        }
    }
    
    // MARK: - Section Views
    
    private var searchBarSection: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search notes or category...", text: $viewModel.searchText)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        addToRecentSearches(viewModel.searchText)
                    }
                    .accessibilityLabel("Search trips")
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                        viewModel.invalidateCache()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding([.horizontal, .top])
    }
    
    private var recentSearchesSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(recentSearches.prefix(5), id: \.self) { search in
                    Button(action: {
                        viewModel.searchText = search
                        viewModel.invalidateCache()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(search)
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                    }
                    .accessibilityLabel("Recent search: \(search)")
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 40)
    }
    
    private var advancedFiltersSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Advanced Filters")
                    .font(.headline)
                Spacer()
                Button("Reset All") {
                    viewModel.resetFilters()
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 10) {
                FilterRow(title: "Date Range") {
                    Picker("Date Range", selection: $viewModel.dateRangeFilter) {
                        ForEach(DateRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                FilterRow(title: "Category") {
                    Picker("Category", selection: $viewModel.selectedReasonFilter) {
                        ForEach(availableReasons, id: \.self) { reason in
                            Text(reason).tag(reason)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Distance Range (km)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Min", value: $viewModel.minDistanceFilter, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                        
                        Text("to")
                            .foregroundColor(.secondary)
                        
                        TextField("Max", value: $viewModel.maxDistanceFilter, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private var tripListSection: some View {
        List {
            if filteredTrips.isEmpty && !tripManager.trips.isEmpty {
                emptyFilteredStateView
            } else if tripManager.trips.isEmpty {
                emptyStateView
            } else {
                ForEach(filteredTrips) { trip in
                    TripRowView(
                        trip: trip,
                        isSelected: viewModel.selectedTripIDs.contains(trip.id),
                        useKilometers: useKilometers,
                        onSelectionToggle: {
                            toggleSelection(for: trip.id)
                        },
                        onTripTap: { selectedTrip = trip }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            deleteTrip(trip)
                        }
                        .tint(.red)

                                                Button("Edit", systemImage: "pencil") {
                                                    editingTrip = trip
                                                }
                                                .tint(.blue)
                                            }
                                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                                Button("Duplicate", systemImage: "doc.on.doc") {
                                                    duplicateTrip(trip)
                                                }
                                                .tint(.green)
                                            }
                                            .contextMenu {
                                                Button("View Details", systemImage: "info.circle") {
                                                    selectedTrip = trip
                                                }

                                                Button("Edit Trip", systemImage: "pencil") {
                                                    editingTrip = trip
                                                }

                                                Button("Duplicate Trip", systemImage: "doc.on.doc") {
                                                    duplicateTrip(trip)
                                                }

                                                Divider()

                                                Button("Share", systemImage: "square.and.arrow.up") {
                                                    shareTrip(trip)
                                                }

                                                Button("Delete", systemImage: "trash", role: .destructive) {
                                                    deleteTrip(trip)
                                                }
                                            }
                                        }
                                    }
                                }
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .refreshable {
                                    viewModel.invalidateCache()
                                }
                                .safeAreaInset(edge: .bottom) {
                                    if !viewModel.selectedTripIDs.isEmpty {
                                        Color.clear.frame(height: 60)
                                    }
                                }
                                .sheet(item: $selectedTrip) { trip in
                                    TripLogDetailView(trip: trip)
                                }
                            }
                            
                            private var emptyStateView: some View {
                                VStack(spacing: 16) {
                                    Image(systemName: "car.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.secondary)
                                    
                                    Text("No Trips Recorded Yet")
                                        .font(.title2.bold())
                                        .foregroundColor(.primary)
                                    
                                    Text("Start a trip to see it here")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    
                                    Button("Import Existing Trips", systemImage: "square.and.arrow.down") {
                                        showImportSheet = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .padding(.top, 8)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                            
                            private var emptyFilteredStateView: some View {
                                VStack(spacing: 16) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 50))
                                        .foregroundColor(.secondary)
                                    
                                    Text("No Trips Found")
                                        .font(.title2.bold())
                                        .foregroundColor(.primary)
                                    
                                    Text("Try adjusting your search or filters")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    
                                    Button("Reset Filters") {
                                        withAnimation {
                                            viewModel.resetFilters()
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .padding(.top, 8)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                            
                            private var toastOverlay: some View {
                                VStack {
                                    if showCopyToast {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.white)
                                            Text("\(copyFormat) copied to clipboard!")
                                                .foregroundColor(.white)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color.green.opacity(0.95))
                                        .cornerRadius(10)
                                        .shadow(radius: 10)
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                        .onAppear {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                withAnimation {
                                                    showCopyToast = false
                                                }
                                            }
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.top, 50)
                                .allowsHitTesting(false)
                            }
                            
                            // MARK: - Helper Functions
                            
                            private func authenticate() {
                                let context = LAContext()
                                var error: NSError?
                                let policy: LAPolicy = tripLogProtectionMethod == "biometric" ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
                                
                                if context.canEvaluatePolicy(policy, error: &error) {
                                    context.evaluatePolicy(policy, localizedReason: "Unlock your trip logs") { success, evalError in
                                        DispatchQueue.main.async {
                                            if success {
                                                withAnimation {
                                                    isAuthenticated = true
                                                    showAuthError = false
                                                }
                                                print("[TripLogView] Authentication successful.")
                                            } else {
                                                isAuthenticated = false
                                                showAuthError = true
                                                authErrorMessage = evalError?.localizedDescription ?? "Authentication failed."
                                            }
                                        }
                                    }
                                } else {
                                    isAuthenticated = false
                                    showAuthError = true
                                    authErrorMessage = error?.localizedDescription ?? "Authentication not available."
                                }
                            }
                            
                            private func toggleSelectAll() {
                                let allIDs = Set(filteredTrips.map { $0.id })
                                withAnimation {
                                    if viewModel.selectedTripIDs == allIDs {
                                        viewModel.selectedTripIDs.removeAll()
                                    } else {
                                        viewModel.selectedTripIDs = allIDs
                                    }
                                }
                            }
                            
                            private func toggleSelection(for id: UUID) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if viewModel.selectedTripIDs.contains(id) {
                                        viewModel.selectedTripIDs.remove(id)
                                    } else {
                                        viewModel.selectedTripIDs.insert(id)
                                    }
                                }
                            }
                            
                            private func deleteTrip(_ trip: Trip) {
                                guard let index = tripManager.trips.firstIndex(where: { $0.id == trip.id }) else { return }
                                
                                let deletedTrip = trip
                                tripManager.deleteTrip(at: IndexSet(integer: index))
                                viewModel.selectedTripIDs.remove(trip.id)
                                viewModel.invalidateCache()
                                
                                undoManager?.registerUndo(withTarget: tripManager) { manager in
                                    manager.trips.append(deletedTrip)
                                    viewModel.selectedTripIDs.remove(deletedTrip.id)
                                    viewModel.invalidateCache()
                                }
                                undoManager?.setActionName("Delete Trip")
                            }
                            
                            private func deleteSelectedTrips() {
                                let tripsToDelete = selectedTrips
                                let indices = tripManager.trips.enumerated()
                                    .filter { viewModel.selectedTripIDs.contains($0.element.id) }
                                    .map { $0.offset }
                                
                                let indexSet = IndexSet(indices)
                                tripManager.deleteTrip(at: indexSet)
                                viewModel.selectedTripIDs.removeAll()
                                viewModel.invalidateCache()
                                
                                undoManager?.registerUndo(withTarget: tripManager) { manager in
                                    tripsToDelete.forEach { manager.trips.append($0) }
                                    viewModel.selectedTripIDs.subtract(tripsToDelete.map { $0.id })
                                    viewModel.invalidateCache()
                                }
                                undoManager?.setActionName("Delete \(tripsToDelete.count) Trips")
                            }
                            
                            private func duplicateTrip(_ trip: Trip) {
                                guard validateTrip(trip) else {
                                    print("Invalid trip data, cannot duplicate")
                                    return
                                }
                                
                                let duplicatedTrip = Trip(
                                    id: UUID(),
                                    date: Date(),
                                    distance: trip.distance,
                                    notes: trip.notes + " (Copy)",
                                    pay: trip.pay,
                                    audioNotes: [],
                                    photoURLs: [],
                                    startCoordinate: trip.startCoordinate,
                                    endCoordinate: trip.endCoordinate,
                                    routeCoordinates: trip.routeCoordinates,
                                    startTime: Date(),
                                    endTime: Date().addingTimeInterval(trip.endTime.timeIntervalSince(trip.startTime)),
                                    reason: trip.reason,
                                    isRecovered: false,
                                    averageSpeed: trip.averageSpeed
                                )
                                
                                tripManager.trips.append(duplicatedTrip)
                                viewModel.invalidateCache()
                                
                                undoManager?.registerUndo(withTarget: tripManager) { manager in
                                    if let index = manager.trips.firstIndex(where: { $0.id == duplicatedTrip.id }) {
                                        manager.deleteTrip(at: IndexSet(integer: index))
                                        viewModel.selectedTripIDs.remove(duplicatedTrip.id)
                                        viewModel.invalidateCache()
                                    }
                                }
                                undoManager?.setActionName("Duplicate Trip")
                            }
                            
                            private func validateTrip(_ trip: Trip) -> Bool {
                                return trip.distance > 0
                                    && trip.endTime > trip.startTime
                                    && (trip.averageSpeed ?? 0) < 300
                            }
                            
                            private func shareTrip(_ trip: Trip) {
                                let formattedDate = trip.startTime.formatted(date: .abbreviated, time: .shortened)
                                let formattedDistance = formatDistance(trip.distance)
                                let duration = formattedDuration(from: trip.startTime, to: trip.endTime)
                                
                                let text = """
                                🚗 Trip Details
                                
                                📅 Date: \(formattedDate)
                                📍 Distance: \(formattedDistance)
                                ⏱️ Duration: \(duration)
                                🏷️ Category: \(trip.reason)
                                📝 Notes: \(trip.notes)
                                \(trip.pay.isEmpty ? "" : "💰 Pay: \(trip.pay)")
                                """
                                
                                let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let rootVC = windowScene.windows.first?.rootViewController {
                                    rootVC.present(activityVC, animated: true)
                                }
                            }
                            
                            private func exportTrips(format: ExportFormat) {
                                guard !viewModel.selectedTripIDs.isEmpty else {
                                    exportError = .noTripsSelected
                                    showExportError = true
                                    return
                                }
                                
                                switch format {
                                case .csv:
                                    exportTripLogsToCSV(selected: selectedTrips)
                                case .json:
                                    exportTripLogsToJSON(selected: selectedTrips)
                                }
                            }
                            
                            private func copyToClipboard(format: ExportFormat) {
                                guard !viewModel.selectedTripIDs.isEmpty else {
                                    exportError = .noTripsSelected
                                    showExportError = true
                                    return
                                }
                                
                                switch format {
                                case .csv:
                                    copyCSVToClipboard(selected: selectedTrips)
                                case .json:
                                    copyJSONToClipboard(selected: selectedTrips)
                                }
                            }
                            
    private func exportTripLogsToCSV(selected: [Trip]) {
        let header = "id,date,distance,notes,pay,audioNotes,photoURLs,startCoordinate,endCoordinate,routeCoordinates,startTime,endTime,reason,isRecovered,averageSpeed\n"
        let rows = selected.map { trip in
            let audioNotesStr = trip.audioNotes.map { $0.absoluteString }.joined(separator: ";")
            let photoURLsStr = trip.photoURLs.map { $0.absoluteString }.joined(separator: ";")
            let startCoordStr = trip.startCoordinate.map { "\($0.latitude),\($0.longitude)" } ?? ""
            let endCoordStr = trip.endCoordinate.map { "\($0.latitude),\($0.longitude)" } ?? ""
            
            let routeCoordStr = trip.routeCoordinates.map { "\($0.latitude),\($0.longitude)" }.joined(separator: ";")
            
            let distanceStr = String(format: "%.4f", trip.distance)
            let avgSpeedStr = trip.averageSpeed != nil ? String(format: "%.4f", trip.averageSpeed!) : ""
            let notesEscaped = trip.notes.replacingOccurrences(of: "\"", with: "\"\"")
            let reasonEscaped = trip.reason.replacingOccurrences(of: "\"", with: "\"\"")
            
            return "\(trip.id.uuidString),\(trip.date),\(distanceStr),\"\(notesEscaped)\",\"\(trip.pay)\",\"\(audioNotesStr)\",\"\(photoURLsStr)\",\"\(startCoordStr)\",\"\(endCoordStr)\",\"\(routeCoordStr)\",\(trip.startTime),\(trip.endTime),\"\(reasonEscaped)\",\(trip.isRecovered),\(avgSpeedStr)"
        }.joined(separator: "\n")
        
        let csvString = header + rows
        
        do {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("TripLogs_\(Date().timeIntervalSince1970).csv")
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            exportURL = tempURL
            showShareSheet = true
        } catch {
            exportError = .fileWriteFailed(error)
            showExportError = true
            print("Failed to create CSV file: \(error)")
        }
    }
                            
    private func copyCSVToClipboard(selected: [Trip]) {
        let header = "id,date,distance,notes,pay,audioNotes,photoURLs,startCoordinate,endCoordinate,routeCoordinates,startTime,endTime,reason,isRecovered,averageSpeed\n"
        let rows = selected.map { trip in
            let audioNotesStr = trip.audioNotes.map { $0.absoluteString }.joined(separator: ";")
            let photoURLsStr = trip.photoURLs.map { $0.absoluteString }.joined(separator: ";")
            let startCoordStr = trip.startCoordinate.map { "\($0.latitude),\($0.longitude)" } ?? ""
            let endCoordStr = trip.endCoordinate.map { "\($0.latitude),\($0.longitude)" } ?? ""
            
            let routeCoordStr = trip.routeCoordinates.map { "\($0.latitude),\($0.longitude)" }.joined(separator: ";")
            
            let distanceStr = String(format: "%.4f", trip.distance)
            let avgSpeedStr = trip.averageSpeed != nil ? String(format: "%.4f", trip.averageSpeed!) : ""
            let notesEscaped = trip.notes.replacingOccurrences(of: "\"", with: "\"\"")
            let reasonEscaped = trip.reason.replacingOccurrences(of: "\"", with: "\"\"")
            
            return "\(trip.id.uuidString),\(trip.date),\(distanceStr),\"\(notesEscaped)\",\"\(trip.pay)\",\"\(audioNotesStr)\",\"\(photoURLsStr)\",\"\(startCoordStr)\",\"\(endCoordStr)\",\"\(routeCoordStr)\",\(trip.startTime),\(trip.endTime),\"\(reasonEscaped)\",\(trip.isRecovered),\(avgSpeedStr)"
        }.joined(separator: "\n")
        
        let csvString = header + rows
        UIPasteboard.general.string = csvString
        
        withAnimation {
            showCopyToast = true
            copyFormat = "CSV"
        }
    }
                            
                            private func exportTripLogsToJSON(selected: [Trip]) {
                                do {
                                    let exportList = selected.map { TripExport(trip: $0) }
                                    let encoder = JSONEncoder()
                                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                                    encoder.dateEncodingStrategy = .iso8601
                                    
                                    let data = try encoder.encode(exportList)
                                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("TripLogs_\(Date().timeIntervalSince1970).json")
                                    try data.write(to: tempURL)
                                    exportURL = tempURL
                                    showShareSheet = true
                                } catch {
                                    exportError = .fileWriteFailed(error)
                                    showExportError = true
                                    print("Failed to create JSON file: \(error)")
                                }
                            }
                            
                            private func copyJSONToClipboard(selected: [Trip]) {
                                do {
                                    let exportList = selected.map { TripExport(trip: $0) }
                                    let encoder = JSONEncoder()
                                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                                    encoder.dateEncodingStrategy = .iso8601
                                    
                                    let data = try encoder.encode(exportList)
                                    if let jsonString = String(data: data, encoding: .utf8) {
                                        UIPasteboard.general.string = jsonString
                                        withAnimation {
                                            showCopyToast = true
                                            copyFormat = "JSON"
                                        }
                                    } else {
                                        throw TripExportError.invalidData
                                    }
                                } catch {
                                    exportError = .encodingFailed
                                    showExportError = true
                                    print("Failed to encode JSON for clipboard: \(error)")
                                }
                            }
                            
                            private func addToRecentSearches(_ search: String) {
                                let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                
                                var searches = recentSearches
                                searches.removeAll { $0 == trimmed }
                                searches.insert(trimmed, at: 0)
                                searches = Array(searches.prefix(10))
                                
                                if let data = try? JSONEncoder().encode(searches) {
                                    recentSearchesData = data
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
                                    
                                    if let duration = audioPlayer?.duration {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.5) {
                                            stopAudioPlayer()
                                        }
                                    }
                                } catch {
                                    audioErrorMessage = "Unable to play audio note: \(error.localizedDescription)"
                                    showAudioErrorAlert = true
                                }
                            }
                            
                            private func stopAudioPlayer() {
                                audioPlayer?.stop()
                                audioPlayer = nil
                            }
                            
                            
                            private func formattedDuration(from start: Date, to end: Date) -> String {
                                formatDuration(end.timeIntervalSince(start))
                            }
                        }

                        // MARK: - Supporting Views

                        struct FilterRow<Content: View>: View {
                            let title: String
                            let content: Content
                            
                            init(title: String, @ViewBuilder content: () -> Content) {
                                self.title = title
                                self.content = content()
                            }
                            
                            var body: some View {
                                HStack {
                                    Text(title)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    content
                                }
                            }
                        }

                        struct StatBox: View {
                            let value: String
                            let label: String
                            let color: Color
                            let icon: String
                            
                            var body: some View {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: icon)
                                            .font(.caption2)
                                        Text(value)
                                            .font(.title3.bold())
                                    }
                                    .foregroundColor(color)
                                    
                                    Text(label)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        struct ImageDetailView: View {
                            let image: UIImage
                            let onClose: () -> Void
                            
                            var body: some View {
                                ZStack {
                                    Color.black.ignoresSafeArea()
                                    
                                    VStack {
                                        HStack {
                                            Spacer()
                                            Button(action: onClose) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.title)
                                                    .foregroundColor(.white)
                                                    .padding()
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .padding()
                                        
                                        Spacer()
                                    }
                                }
                            }
                        }

                        struct BulkEditView: View {
                            let trips: [Trip]
                            let onSave: ([Trip]) -> Void
                            @Environment(\.dismiss) private var dismiss
                            
                            @State private var newReason: String = ""
                            @State private var newPay: String = ""
                            @State private var applyReason = false
                            @State private var applyPay = false
                            
                            var body: some View {
                                NavigationView {
                                    Form {
                                        Section("Bulk Edit \(trips.count) Trips") {
                                            Toggle("Update Category", isOn: $applyReason)
                                            if applyReason {
                                                TextField("New Category", text: $newReason)
                                            }
                                            
                                            Toggle("Update Pay", isOn: $applyPay)
                                            if applyPay {
                                                TextField("New Pay", text: $newPay)
                                                    .keyboardType(.decimalPad)
                                            }
                                        }
                                        
                                        Section {
                                            Text("This will update all \(trips.count) selected trips")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .navigationTitle("Bulk Edit")
                                    .navigationBarTitleDisplayMode(.inline)
                                    .toolbar {
                                        ToolbarItem(placement: .cancellationAction) {
                                            Button("Cancel") { dismiss() }
                                        }
                                        ToolbarItem(placement: .confirmationAction) {
                                            Button("Save") {
                                                saveBulkChanges()
                                            }
                                            .disabled(!applyReason && !applyPay)
                                        }
                                    }
                                }
                            }
                            
                            private func saveBulkChanges() {
                                var updatedTrips = trips
                                
                                for i in 0..<updatedTrips.count {
                                    var trip = updatedTrips[i]
                                    if applyReason {
                                        trip.reason = newReason
                                    }
                                    if applyPay {
                                        trip.pay = newPay
                                    }
                                    updatedTrips[i] = trip
                                }
                                
                                onSave(updatedTrips)
                                dismiss()
                            }
                        }

struct ImportTripsView: View {
    let onImport: ([Trip]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showDocumentPicker = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text("Import Trips")
                    .font(.title.bold())
                
                Text("Import trips from CSV or JSON files")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if isProcessing {
                    ProgressView("Processing...")
                        .padding()
                } else {
                    Button("Choose File", systemImage: "folder") {
                        showDocumentPicker = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding()
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(isPresented: $showDocumentPicker) { url in
                    processImportedFile(url)
                }
            }
            .alert("Import Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func processImportedFile(_ url: URL) {
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let didStartAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                let data = try Data(contentsOf: url)
                var trips: [Trip] = []
                
                if url.pathExtension.lowercased() == "json" {
                    trips = try parseJSON(data)
                } else if url.pathExtension.lowercased() == "csv" {
                    trips = try parseCSV(data)
                } else {
                    throw ImportError.unsupportedFormat
                }
                
                DispatchQueue.main.async {
                    isProcessing = false
                    if !trips.isEmpty {
                        onImport(trips)
                        dismiss()
                    } else {
                        errorMessage = "No valid trips found in file"
                        showError = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func parseJSON(_ data: Data) throws -> [Trip] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let exportedTrips = try decoder.decode([TripExport].self, from: data)
        return exportedTrips.map { exported in
            Trip(
                id: exported.id,
                date: exported.date,
                distance: exported.distance,
                notes: exported.notes,
                pay: exported.pay,
                audioNotes: exported.audioNotes,
                photoURLs: exported.photoURLs,
                startCoordinate: exported.startCoordinate,
                endCoordinate: exported.endCoordinate,
                routeCoordinates: exported.routeCoordinates,
                startTime: exported.startTime,
                endTime: exported.endTime,
                reason: exported.reason,
                isRecovered: exported.isRecovered,
                averageSpeed: exported.averageSpeed
            )
        }
    }
    
    private func parseCSV(_ data: Data) throws -> [Trip] {
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidEncoding
        }
        
        let lines = csvString.components(separatedBy: .newlines)
        guard lines.count > 1 else {
            throw ImportError.emptyFile
        }
        
        var trips: [Trip] = []
        let dateFormatter = ISO8601DateFormatter()
        
        for line in lines.dropFirst() {
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            
            let fields = parseCSVLine(line)
            guard fields.count >= 14 else { continue }
            
            guard let id = UUID(uuidString: fields[0]),
                  let date = dateFormatter.date(from: fields[1]),
                  let distance = Double(fields[2]),
                  let startTime = dateFormatter.date(from: fields[10]),
                  let endTime = dateFormatter.date(from: fields[11]) else {
                continue
            }
            
            let notes = fields[3]
            let pay = fields[4]
            let reason = fields[12]
            let isRecovered = fields[13].lowercased() == "true"
            let averageSpeed = fields.count > 14 ? Double(fields[14]) : nil
            
            var startCoord: CodableCoordinate? = nil
            var endCoord: CodableCoordinate? = nil
            var routeCoords: [CodableCoordinate] = []
            
            if !fields[7].isEmpty {
                let coords = fields[7].components(separatedBy: ",")
                if coords.count == 2, let lat = Double(coords[0]), let lon = Double(coords[1]) {
                    startCoord = CodableCoordinate(latitude: lat, longitude: lon)
                }
            }
            
            if !fields[8].isEmpty {
                let coords = fields[8].components(separatedBy: ",")
                if coords.count == 2, let lat = Double(coords[0]), let lon = Double(coords[1]) {
                    endCoord = CodableCoordinate(latitude: lat, longitude: lon)
                }
            }
            
            if !fields[9].isEmpty {
                let coordPairs = fields[9].components(separatedBy: ";")
                for pair in coordPairs {
                    let coords = pair.components(separatedBy: ",")
                    if coords.count == 2, let lat = Double(coords[0]), let lon = Double(coords[1]) {
                        routeCoords.append(CodableCoordinate(latitude: lat, longitude: lon))
                    }
                }
            }
            
            let trip = Trip(
                id: id,
                date: date,
                distance: distance,
                notes: notes,
                pay: pay,
                audioNotes: [],
                photoURLs: [],
                startCoordinate: startCoord,
                endCoordinate: endCoord,
                routeCoordinates: routeCoords,
                startTime: startTime,
                endTime: endTime,
                reason: reason,
                isRecovered: isRecovered,
                averageSpeed: averageSpeed
            )
            
            trips.append(trip)
        }
        
        return trips
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        fields.append(currentField)
        
        return fields.map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

enum ImportError: LocalizedError {
    case accessDenied
    case unsupportedFormat
    case invalidEncoding
    case emptyFile
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Unable to access the selected file"
        case .unsupportedFormat:
            return "Unsupported file format. Please select a CSV or JSON file"
        case .invalidEncoding:
            return "Unable to read file content"
        case .emptyFile:
            return "The selected file is empty"
        }
    }
}
                        // MARK: - Trip Row View

struct TripRowView: View {
    let trip: Trip
    let isSelected: Bool
    let useKilometers: Bool
    let onSelectionToggle: () -> Void
    let onTripTap: () -> Void
    
    private func formatDistanceFromMiles(_ miles: Double) -> String {
        if miles == 0 {
            return useKilometers ? "0 km" : "0 mi"
        }
        
        if useKilometers {
            let km = miles * 1.60934
            return String(format: "%.2f km", km)
        } else {
            return String(format: "%.2f mi", miles)
        }
    }
    
    private var formattedDistance: String {
        return formatDistanceFromMiles(trip.distance)
    }
    
    private var formattedDuration: String {
        let interval = Int(trip.endTime.timeIntervalSince(trip.startTime))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var formattedAverageSpeed: String {
        if let avgSpeed = trip.averageSpeed, avgSpeed > 0 {
            return AverageSpeedFormatter.string(forMetersPerSecond: avgSpeed, useKilometers: useKilometers)
        }
        
        let duration = trip.endTime.timeIntervalSince(trip.startTime)
        
        guard duration > 0 else {
            return useKilometers ? "0 km/h" : "0 mph"
        }
        
        let distanceMiles = trip.distance
        let speedMPH = (distanceMiles / duration) * 3600
        
        if useKilometers {
            let speedKMH = speedMPH * 1.60934
            return String(format: "%.1f km/h", speedKMH)
        } else {
            return String(format: "%.1f mph", speedMPH)
        }
    }
    
    private var hasMedia: Bool {
        !trip.audioNotes.isEmpty || !trip.photoURLs.isEmpty
    }
    
    var body: some View {
        return HStack(spacing: 12) {
            Button(action: onSelectionToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.title3)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(isSelected ? "Deselect trip" : "Select trip")
            
            Button(action: onTripTap) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(trip.startTime.formatted(date: .abbreviated, time: .shortened))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "road.lanes")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Text(formatDistanceFromMiles(trip.distance))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text(formattedDuration)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "speedometer")
                                .font(.caption)
                            Text(formattedAverageSpeed)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            if !trip.photoURLs.isEmpty {
                                Image(systemName: "photo")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            if !trip.audioNotes.isEmpty {
                                Image(systemName: "waveform")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            if trip.isRecovered {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    
                    if !trip.reason.isEmpty {
                        Text(trip.reason)
                            .font(.subheadline)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.regularMaterial, in: Capsule())
                            .foregroundColor(.secondary)
                    }
                    
                    if !trip.notes.isEmpty {
                        Text(trip.notes)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    
                    if !trip.pay.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(trip.pay)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: onTripTap) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("View trip details")
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Trip from \(trip.startTime.formatted()) covering \(formattedDistance)")
        .accessibilityHint("Double tap to view details")
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.json, .commaSeparatedText],
            asCopy: true
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
            parent.isPresented = false
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}

    // MARK: - Preview
    
#if DEBUG
    struct TripLogView_Previews: PreviewProvider {
        static var previews: some View {
            TripLogView()
                .environmentObject(TripManager())
        }
    }
#endif


