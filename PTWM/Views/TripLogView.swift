// NOTE: Unlocking with Face ID only removes the overlay, does not dismiss the screen or switch tabs.

import SwiftUI
import MapKit
import UniformTypeIdentifiers
import AVFoundation
import LocalAuthentication

struct TripLogView: View {
    @State private var navigationStackActive = false
    @State private var selectedTrip: Trip? = nil
    
    @EnvironmentObject var tripManager: TripManager
    @StateObject private var premiumManager = PremiumManager.shared // Add PremiumManager shared instance
    @Environment(\.scenePhase) private var scenePhase
    
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
    
    @State private var selectedFullImage: UIImage? = nil
    
    @State private var selectedTripIDs: Set<UUID> = []
    
    @State private var sortOption: SortOption = .dateDescending
    
    @State private var showDeleteConfirmation = false
    
    @State private var searchText: String = ""
    @State private var showAdvancedFilters = false
    @State private var dateRangeFilter: DateRange = .all
    @State private var minDistanceFilter: Double = 0
    @State private var maxDistanceFilter: Double = 1000
    @State private var selectedReasonFilter: String = "All"
    @AppStorage("recentSearches") private var recentSearchesData: Data = Data()
    
    enum DateRange: String, CaseIterable, Identifiable {
        case all = "All Time"
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case last3Months = "Last 3 Months"
        
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
            }
        }
    }
    
    var recentSearches: [String] {
        (try? JSONDecoder().decode([String].self, from: recentSearchesData)) ?? []
    }
    
    var availableReasons: [String] {
        let reasons = Set(tripManager.trips.map { $0.reason }.filter { !$0.isEmpty })
        return ["All"] + Array(reasons).sorted()
    }
    
    @State private var showCopyToast = false
    @State private var copyFormat: String = "CSV"
    @State private var showStatistics = false
    
    var totalStats: (distance: Double, duration: TimeInterval, earnings: Double, count: Int) {
        let trips = filteredTrips
        let totalDistance = trips.reduce(0) { $0 + $1.distance }
        let totalDuration = trips.reduce(0) { $0 + $1.endTime.timeIntervalSince($1.startTime) }
        let totalEarnings = trips.compactMap { Double($0.pay) }.reduce(0, +)
        return (totalDistance, totalDuration, totalEarnings, trips.count)
    }
    
    @State private var didAttemptInitialAuth = false
    
    enum SortOption: String, CaseIterable, Identifiable {
        case dateDescending = "Date (Newest)"
        case dateAscending = "Date (Oldest)"
        case distanceDescending = "Distance (Longest)"
        case distanceAscending = "Distance (Shortest)"
        case timeDescending = "Time (Longest)"
        case timeAscending = "Time (Shortest)"
        var id: String { rawValue }
    }
    
    // For JSON export, we omit routeCoordinates for privacy/size reasons
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
            self.startTime = trip.startTime
            self.endTime = trip.endTime
            self.reason = trip.reason
            self.isRecovered = trip.isRecovered
            self.averageSpeed = trip.averageSpeed
        }
    }
    
    var selectedTrips: [Trip] {
        tripManager.trips.filter { selectedTripIDs.contains($0.id) }
    }
    
    @State private var cachedFilteredTrips: [Trip] = []
    @State private var lastSearchText: String = ""
    @State private var lastSortOption: SortOption = .dateDescending
    
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
    
    // Optimized filtering with caching
    var filteredTrips: [Trip] {
        // Check if we need to recalculate
        if searchText != lastSearchText || sortOption != lastSortOption || cachedFilteredTrips.isEmpty {
            let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            var results = sortedTrips
            
            // Apply text search
            if !trimmedSearch.isEmpty {
                results = results.filter {
                    $0.notes.localizedCaseInsensitiveContains(trimmedSearch) ||
                    $0.reason.localizedCaseInsensitiveContains(trimmedSearch)
                }
            }
            
            // Apply date range filter
            if let range = dateRangeFilter.dateRange {
                results = results.filter { trip in
                    trip.startTime >= range.start && trip.startTime <= range.end
                }
            }
            
            // Apply reason filter
            if selectedReasonFilter != "All" {
                results = results.filter { $0.reason == selectedReasonFilter }
            }
            
            cachedFilteredTrips = results
            lastSearchText = searchText
            lastSortOption = sortOption
        }
        
        return cachedFilteredTrips
    }
    
    private func addToRecentSearches(_ search: String) {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var searches = recentSearches
        searches.removeAll { $0 == trimmed }
        searches.insert(trimmed, at: 0)
        searches = Array(searches.prefix(10)) // Keep only 10 most recent
        
        if let data = try? JSONEncoder().encode(searches) {
            recentSearchesData = data
        }
    }
    
    private func resetFilters() {
        dateRangeFilter = .all
        selectedReasonFilter = "All"
        minDistanceFilter = 0
        maxDistanceFilter = 1000
        searchText = ""
        cachedFilteredTrips = []
    }
    
    private func deleteTripById(_ id: UUID) {
        if let index = tripManager.trips.firstIndex(where: { $0.id == id }) {
            tripManager.deleteTrip(at: IndexSet(integer: index))
        }
        selectedTripIDs.remove(id)
        cachedFilteredTrips = []
    }
    
    private func duplicateTrip(_ trip: Trip) {
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
        cachedFilteredTrips = []
    }
    
    private func shareTrip(_ trip: Trip) {
        let formattedDate = trip.startTime.formatted(date: .abbreviated, time: .shortened)
        let formattedDistance: String
        if useKilometers {
            formattedDistance = String(format: "%.2f km", trip.distance / 1000)
        } else {
            formattedDistance = String(format: "%.2f mi", trip.distance * 0.000621371)
        }
        
        let text = """
        Trip Details:
        Date: \(formattedDate)
        Distance: \(formattedDistance)
        Category: \(trip.reason)
        Notes: \(trip.notes)
        """
        
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(activityVC, animated: true)
    }
    
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
            Text("Trip Log Locked")
                .font(.title)
            Text("Authenticate to view your trip logs.")
                .font(.body)
                .padding(.bottom)
            Button("Authenticate") {
                authenticate()
            }
            .buttonStyle(.borderedProminent)
            if showAuthError {
                Text(authErrorMessage)
                    .foregroundColor(.red)
                    .padding(.top)
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
            VStack {
                VStack {
                    searchBarSection
                    
                    recentSearchesSection
                    
                    advancedFiltersSection
                    
                    exportMenuSection
                    
                    controlButtonsSection
                    
                    statisticsSummarySection
                    
                    tripListSection
                }
                .toolbar(id: "trip-log-toolbar") {
                    // Customizable toolbar with moveable items
                    ToolbarItem(id: "search", placement: .topBarLeading) {
                        Button("Toggle Search", systemImage: "magnifyingglass") {
                            showAdvancedFilters.toggle()
                        }
                    }
                    
                    ToolbarItem(id: "statistics", placement: .topBarTrailing) {
                        Button("Stats", systemImage: "chart.line.uptrend.xyaxis") {
                            showStatistics.toggle()
                        }
                    }
                    
                    ToolbarItem(id: "export", placement: .topBarTrailing) {
                        Menu {
                            Button("Export as CSV", systemImage: "doc.text") {
                                exportTripLogsToCSV(selected: selectedTrips)
                            }
                            .disabled(!premiumManager.isPremium)
                            
                            Button("Export as JSON", systemImage: "curlybraces") {
                                exportTripLogsToJSON(selected: selectedTrips)
                            }
                            .disabled(!premiumManager.isPremium)
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .disabled(selectedTripIDs.isEmpty)
                    }
                    
                    if #available(iOS 26.0, *) {
                        ToolbarSpacer()
                    } else {<#result#>
                        // Fallback on earlier versions
                    }
                    
                    ToolbarItem(id: "selection", placement: .bottomBar) {
                        Button(selectedTripIDs == Set(filteredTrips.map { $0.id }) ? "Deselect All" : "Select All") {
                            let allIDs = Set(filteredTrips.map { $0.id })
                            if selectedTripIDs == allIDs {
                                selectedTripIDs.removeAll()
                            } else {
                                selectedTripIDs = allIDs
                            }
                        }
                        .font(.subheadline.bold())
                    }
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
                .alert("Delete Selected Logs?", isPresented: $showDeleteConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) { deleteSelectedTrips() }
                } message: {
                    Text("This action is permanent and cannot be undone. Are you sure you want to delete the selected logs?")
                }
                .overlay(
                    VStack {
                        if showCopyToast {
                            Text("\(copyFormat) copied to clipboard!")
                                .padding(10)
                                .background(Color.secondary.opacity(0.95))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
                                        withAnimation { showCopyToast = false }
                                    }
                                }
                        }
                        Spacer()
                    }
                        .padding(.top, 36)
                )
                .onAppear {
                    if tripLogProtectionEnabled && !isAuthenticated {
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
        }
    }
    
    // MARK: - View Component Sections
    
    private var searchBarSection: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search notes or category...", text: $searchText)
                    .disableAutocorrection(true)
                    .onSubmit {
                        addToRecentSearches(searchText)
                    }
            }
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            
            Button(action: { showAdvancedFilters.toggle() }) {
                Image(systemName: showAdvancedFilters ? "slider.horizontal.3" : "slider.horizontal.below.rectangle")
                    .foregroundColor(.accentColor)
            }
            .padding(.leading, 4)
        }
        .padding([.horizontal, .top])
    }
    
    private var recentSearchesSection: some View {
        Group {
            if !searchText.isEmpty || !recentSearches.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(recentSearches.prefix(5), id: \.self) { search in
                            Button(search) {
                                searchText = search
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.regularMaterial, in: Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: recentSearches.isEmpty ? 0 : 30)
            }
        }
    }
    
    private var advancedFiltersSection: some View {
        Group {
            if showAdvancedFilters {
                VStack(spacing: 12) {
                    HStack {
                        Text("Filters")
                            .font(.headline)
                        Spacer()
                        Button("Reset") {
                            resetFilters()
                        }
                        .font(.caption)
                    }
                    
                    HStack {
                        Text("Date Range:")
                        Spacer()
                        Picker("Date Range", selection: $dateRangeFilter) {
                            ForEach(DateRange.allCases) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    HStack {
                        Text("Category:")
                        Spacer()
                        Picker("Category", selection: $selectedReasonFilter) {
                            ForEach(availableReasons, id: \.self) { reason in
                                Text(reason).tag(reason)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
    }
    
    private var exportMenuSection: some View {
        VStack {
            Menu {
                // Disable export options if not premium
                Button("Export as CSV", systemImage: "doc.text") {
                    exportTripLogsToCSV(selected: selectedTrips)
                }
                .disabled(!premiumManager.isPremium) // Premium gating
                
                Button("Export as JSON", systemImage: "curlybraces") {
                    exportTripLogsToJSON(selected: selectedTrips)
                }
                .disabled(!premiumManager.isPremium) // Premium gating
                
                Button("Copy CSV to Clipboard", systemImage: "doc.on.doc") {
                    copyCSVToClipboard(selected: selectedTrips)
                }
                .disabled(!premiumManager.isPremium) // Premium gating
                
                Button("Copy JSON to Clipboard", systemImage: "chevron.left.slash.chevron.right") {
                    copyJSONToClipboard(selected: selectedTrips)
                }
                .disabled(!premiumManager.isPremium) // Premium gating
            } label: {
                Label("Export Trip Logs (Premium)", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .disabled(selectedTripIDs.isEmpty)
            
            // Show premium feature notice if not premium
            if !premiumManager.isPremium {
                Text("Exporting trip logs is a Premium feature.")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.bottom, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
        }
    }
    
    private var controlButtonsSection: some View {
        VStack {
            Button(action: { showDeleteConfirmation = true }) {
                Label("Delete Selected Logs", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .padding(.bottom, 5)
            .frame(maxWidth: .infinity)
            .disabled(selectedTripIDs.isEmpty)
            
            HStack {
                Button(action: {
                    let allIDs = Set(filteredTrips.map { $0.id })
                    if selectedTripIDs == allIDs {
                        selectedTripIDs.removeAll()
                    } else {
                        selectedTripIDs = allIDs
                    }
                }) {
                    Text(selectedTripIDs == Set(filteredTrips.map { $0.id }) ? "Deselect All" : "Select All")
                        .font(.subheadline.bold())
                }
                Spacer()
                Menu {
                    ForEach(SortOption.allCases) { option in
                        Button(option.rawValue) { sortOption = option }
                    }
                } label: {
                    Label("Sort by: \(sortOption.rawValue)", systemImage: "arrow.up.arrow.down")
                        .font(.subheadline.bold())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }
    
    private var statisticsSummarySection: some View {
        Group {
            if !filteredTrips.isEmpty {
                Button(action: { showStatistics.toggle() }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Trip Summary")
                                .font(.headline)
                            HStack(spacing: 16) {
                                VStack(alignment: .leading) {
                                    Text("\(totalStats.count)")
                                        .font(.title2.bold())
                                        .foregroundColor(.accentColor)
                                    Text("Trips")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack(alignment: .leading) {
                                    let formattedDistance = useKilometers ?
                                    String(format: "%.1f km", totalStats.distance / 1000) :
                                    String(format: "%.1f mi", totalStats.distance * 0.000621371)
                                    Text(formattedDistance)
                                        .font(.title2.bold())
                                        .foregroundColor(.blue)
                                    Text("Distance")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if totalStats.earnings > 0 {
                                    VStack(alignment: .leading) {
                                        Text("$\(totalStats.earnings, specifier: "%.2f")")
                                            .font(.title2.bold())
                                            .foregroundColor(.green)
                                        Text("Earnings")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: showStatistics ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .buttonStyle(PlainButtonStyle())
                
                if showStatistics {
                    VStack(spacing: 12) {
                        HStack {
                            VStack {
                                Text("Average Distance")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                let avgDistance = totalStats.count > 0 ? totalStats.distance / Double(totalStats.count) : 0
                                let formattedAvgDistance = useKilometers ?
                                String(format: "%.2f km", avgDistance / 1000) :
                                String(format: "%.2f mi", avgDistance * 0.000621371)
                                Text(formattedAvgDistance)
                                    .font(.headline)
                            }
                            
                            Spacer()
                            
                            VStack {
                                Text("Average Duration")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                let avgDuration = totalStats.count > 0 ? totalStats.duration / Double(totalStats.count) : 0
                                let hours = Int(avgDuration) / 3600
                                let minutes = (Int(avgDuration) % 3600) / 60
                                Text(hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m")
                                    .font(.headline)
                            }
                            
                            if totalStats.earnings > 0 {
                                Spacer()
                                
                                VStack {
                                    Text("Avg Earnings/Trip")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    let avgEarnings = totalStats.count > 0 ? totalStats.earnings / Double(totalStats.count) : 0
                                    Text("$\(avgEarnings, specifier: "%.2f")")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var tripListSection: some View {
        List {
            if filteredTrips.isEmpty && !tripManager.trips.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No trips found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Try adjusting your search or filters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if tripManager.trips.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No trips recorded yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Start a trip to see it here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(filteredTrips) { trip in
                    TripRowView(
                        trip: trip,
                        isSelected: selectedTripIDs.contains(trip.id),
                        useKilometers: useKilometers,
                        onSelectionToggle: {
                            if selectedTripIDs.contains(trip.id) {
                                selectedTripIDs.remove(trip.id)
                            } else {
                                selectedTripIDs.insert(trip.id)
                            }
                        },
                        onTripTap: { selectedTrip = trip }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", systemImage: "trash") {
                            deleteTripById(trip.id)
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
                            deleteTripById(trip.id)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .refreshable {
            // Clear cache to force refresh
            cachedFilteredTrips = []
        }
        .sheet(item: $selectedTrip) { trip in
            TripLogDetailView(trip: trip)
        }
    }
    
    // MARK: - Helper Functions
    
    func authenticate() {
        let context = LAContext()
        var error: NSError?
        let policy: LAPolicy = tripLogProtectionMethod == "biometric" ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        if context.canEvaluatePolicy(policy, error: &error) {
            context.evaluatePolicy(policy, localizedReason: "Unlock your trip logs") { success, evalError in
                DispatchQueue.main.async {
                    if success {
                        isAuthenticated = true
                        showAuthError = false
                        // Unlocking now only dismisses the lock overlay, does not dismiss the view or navigate elsewhere.
                        print("[TripLogView] Face ID unlock successful. Lock overlay dismissed, staying on log page.")
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
    
    func deleteTrip(at offsets: IndexSet) {
        tripManager.deleteTrip(at: offsets)
    }
    
    func deleteSelectedTrips() {
        let indices = tripManager.trips.enumerated().filter { selectedTripIDs.contains($0.element.id) }.map { $0.offset }
        let indexSet = IndexSet(indices)
        tripManager.deleteTrip(at: indexSet)
        selectedTripIDs.removeAll()
    }
    
    func exportTripLogsToCSV(selected: [Trip]) {
        let header = "id,date,distance,notes,pay,audioNotes,photoURLs,startCoordinate,endCoordinate,startTime,endTime,reason,isRecovered,averageSpeed\n"
        let rows = selected.map { trip in
            let audioNotesStr = trip.audioNotes.map { $0.absoluteString }.joined(separator: ";")
            let photoURLsStr = trip.photoURLs.map { $0.absoluteString }.joined(separator: ";")
            let startCoordStr = trip.startCoordinate.map { "\($0.latitude),\($0.longitude)" } ?? ""
            let endCoordStr = trip.endCoordinate.map { "\($0.latitude),\($0.longitude)" } ?? ""
            let distanceStr = String(format: "%.4f", trip.distance)
            let avgSpeedStr = trip.averageSpeed != nil ? String(format: "%.4f", trip.averageSpeed!) : ""
            let notesEscaped = trip.notes.replacingOccurrences(of: "\"", with: "\"\"")
            let reasonEscaped = trip.reason.replacingOccurrences(of: "\"", with: "\"\"")
            return "\(trip.id.uuidString),\(trip.date),\(distanceStr),\"\(notesEscaped)\",\"\(trip.pay)\",\"\(audioNotesStr)\",\"\(photoURLsStr)\",\"\(startCoordStr)\",\"\(endCoordStr)\",\(trip.startTime),\(trip.endTime),\"\(reasonEscaped)\",\(trip.isRecovered),\(avgSpeedStr)"
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
    
    func copyCSVToClipboard(selected: [Trip]) {
        let header = "id,date,distance,notes,pay,audioNotes,photoURLs,startCoordinate,endCoordinate,startTime,endTime,reason,isRecovered,averageSpeed\n"
        let rows = selected.map { trip in
            let audioNotesStr = trip.audioNotes.map { $0.absoluteString }.joined(separator: ";")
            let photoURLsStr = trip.photoURLs.map { $0.absoluteString }.joined(separator: ";")
            let startCoordStr = trip.startCoordinate.map { "\($0.latitude),\($0.longitude)" } ?? ""
            let endCoordStr = trip.endCoordinate.map { "\($0.latitude),\($0.longitude)" } ?? ""
            let distanceStr = String(format: "%.4f", trip.distance)
            let avgSpeedStr = trip.averageSpeed != nil ? String(format: "%.4f", trip.averageSpeed!) : ""
            let notesEscaped = trip.notes.replacingOccurrences(of: "\"", with: "\"\"")
            let reasonEscaped = trip.reason.replacingOccurrences(of: "\"", with: "\"\"")
            return "\(trip.id.uuidString),\(trip.date),\(distanceStr),\"\(notesEscaped)\",\"\(trip.pay)\",\"\(audioNotesStr)\",\"\(photoURLsStr)\",\"\(startCoordStr)\",\"\(endCoordStr)\",\(trip.startTime),\(trip.endTime),\"\(reasonEscaped)\",\(trip.isRecovered),\(avgSpeedStr)"
        }.joined(separator: "\n")
        let csvString = header + rows
        UIPasteboard.general.string = csvString
        showCopyToast = true
        copyFormat = "CSV"
    }
    
    func exportTripLogsToJSON(selected: [Trip]) {
        do {
            let exportList = selected.map { TripExport(trip: $0) }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(exportList)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("TripLogs.json")
            try data.write(to: tempURL)
            exportURL = tempURL
            showShareSheet = true
        } catch {
            print("Failed to create JSON file: \(error)")
        }
    }
    
    func copyJSONToClipboard(selected: [Trip]) {
        do {
            let exportList = selected.map { TripExport(trip: $0) }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(exportList)
            if let jsonString = String(data: data, encoding: .utf8) {
                UIPasteboard.general.string = jsonString
                showCopyToast = true
                copyFormat = "JSON"
            }
        } catch {
            print("Failed to encode JSON for clipboard: \(error)")
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
    
struct TripRowView: View {
    let trip: Trip
    let isSelected: Bool
    let useKilometers: Bool
    let onSelectionToggle: () -> Void
    let onTripTap: () -> Void
    
    private var formattedDistance: String {
        if useKilometers {
            let km = trip.distance / 1000
            return String(format: "%.2f km", km)
        } else {
            let miles = trip.distance * 0.000621371
            return String(format: "%.2f mi", miles)
        }
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
    
    private var hasMedia: Bool {
        !trip.audioNotes.isEmpty || !trip.photoURLs.isEmpty
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            Button(action: onSelectionToggle) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Trip content
            Button(action: onTripTap) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trip.startTime.formatted(date: .abbreviated, time: .shortened))
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 8) {
                                Label(formattedDistance, systemImage: "road.lanes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Label(formattedDuration, systemImage: "clock")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let avgSpeed = trip.averageSpeed {
                                    Label(AverageSpeedFormatter.string(forMetersPerSecond: avgSpeed, useKilometers: useKilometers),
                                          systemImage: "speedometer")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            if hasMedia {
                                HStack(spacing: 4) {
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
                                }
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
                            .padding(.vertical, 2)
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
                        HStack {
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
            
            // Detail button
            Button(action: onTripTap) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

struct AverageSpeedFormatter {
    static func string(forMetersPerSecond speed: Double, useKilometers: Bool) -> String {
        if useKilometers {
            // convert m/s to km/h
            let kmh = speed * 3.6
            return String(format: "%.1f km/h", kmh)
        } else {
            // convert m/s to mph
            let mph = speed * 2.23694
            return String(format: "%.1f mph", mph)
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

#if DEBUG
struct TripLogView_Previews: PreviewProvider {
    static var previews: some View {
        TripLogView()
            .environmentObject(TripManager())
            .environmentObject(PremiumManager.shared) // Provide PremiumManager environment object to preview
    }
}
#endif

