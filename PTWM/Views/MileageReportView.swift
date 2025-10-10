// NOTE: Unlocking with Face ID only removes the overlay, does not dismiss the screen or switch tabs.
import SwiftUI
import Charts
import LocalAuthentication
import UniformTypeIdentifiers

struct MileageReportView: View {
    @EnvironmentObject var tripManager: TripManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("useKilometers") private var useKilometers: Bool = false
    @AppStorage("tripCategories") private var tripCategoriesData: String = ""
    @AppStorage("tripLogProtectionEnabled") private var tripLogProtectionEnabled: Bool = false
    @AppStorage("tripLogProtectionMethod") private var tripLogProtectionMethod: String = "biometric"
    @AppStorage("mileageReportSelectedFilter") private var savedSelectedFilterRawValue: String = TimeFilter.last7.rawValue
    
    @State private var selectedCategory: String = "All"
    @State private var isAuthenticated = false
    @State private var showAuthError = false
    @State private var authErrorMessage = ""
    @State private var didAttemptInitialAuth = false
    @State private var selectedFilter: TimeFilter = TimeFilter(rawValue: UserDefaults.standard.string(forKey: "mileageReportSelectedFilter") ?? TimeFilter.last7.rawValue) ?? .last7
    @State private var showingExportSheet = false
    @State private var exportDocument: CSVDocument?
    @State private var showingDateRangePicker = false
    @State private var customStartDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var customEndDate = Date()
    
    enum TimeFilter: String, CaseIterable, Identifiable {
        case last7 = "7 Days"
        case last30 = "30 Days"
        case last90 = "3 Months"
        case last365 = "Year"
        case all = "All Time"
        case custom = "Custom"
        var id: String { self.rawValue }
    }
    
    struct DailyMileage: Identifiable {
        let id = UUID()
        let date: Date
        let miles: Double
        let duration: TimeInterval
    }
    
    struct DailyMetric: Identifiable {
        let id = UUID()
        let date: Date
        let type: String
        let value: Double
    }
    
    struct CSVDocument: FileDocument {
        static var readableContentTypes: [UTType] { [.commaSeparatedText] }
        
        var text: String
        
        init(text: String) {
            self.text = text
        }
        
        init(configuration: ReadConfiguration) throws {
            self.text = configuration.file.regularFileContents.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        }
        
        func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
            let data = text.data(using: .utf8) ?? Data()
            return FileWrapper(regularFileWithContents: data)
        }
    }
    
    private var supportedCategories: [String] {
        let defaults = [
            "All",
            "Business",
            "Personal",
            "Vacation",
            "Photography",
            "DoorDash",
            "Uber",
            "Other"
        ]
        let custom: [String]
        if let decoded = try? JSONDecoder().decode([String].self, from: Data(tripCategoriesData.utf8)), !decoded.isEmpty {
            custom = decoded
        } else {
            custom = [
                "Business", "Personal", "Vacation", "Photography", "DoorDash", "Uber", "Other"
            ]
        }
        return ["All"] + custom.filter { $0 != "All" }
    }
    
    private var filteredTrips: [Trip] {
        let now = Date()
        let calendar = Calendar.current
        
        switch selectedFilter {
        case .all:
            return tripManager.trips
        case .custom:
            let startOfDay = calendar.startOfDay(for: customStartDate)
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: customEndDate) ?? customEndDate
            return tripManager.trips.filter { $0.startTime >= startOfDay && $0.startTime <= endOfDay }
        case .last7:
            guard let startDate = calendar.date(byAdding: .day, value: -7, to: now) else { return tripManager.trips }
            return tripManager.trips.filter { $0.startTime >= startDate }
        case .last30:
            guard let startDate = calendar.date(byAdding: .day, value: -30, to: now) else { return tripManager.trips }
            return tripManager.trips.filter { $0.startTime >= startDate }
        case .last90:
            guard let startDate = calendar.date(byAdding: .day, value: -90, to: now) else { return tripManager.trips }
            return tripManager.trips.filter { $0.startTime >= startDate }
        case .last365:
            guard let startDate = calendar.date(byAdding: .day, value: -365, to: now) else { return tripManager.trips }
            return tripManager.trips.filter { $0.startTime >= startDate }
        }
    }
    
    var filteredTripsByCategory: [Trip] {
        let mainCategories = supportedCategories
            .filter { $0 != "All" && $0 != "Other" }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        
        switch selectedCategory {
        case "All":
            return filteredTrips
        case "Other":
            return filteredTrips.filter {
                let reason = $0.reason.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return !reason.isEmpty && !mainCategories.contains(reason)
            }
        default:
            return filteredTrips.filter {
                $0.reason.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == selectedCategory.lowercased()
            }
        }
    }
    
    var totalMiles: Double {
        filteredTripsByCategory.reduce(0) { $0 + $1.distance }
    }
    
    var showThousandsOfMiles: Bool {
        !useKilometers && totalMiles >= 1000
    }
    
    var totalDistanceDisplay: String {
        if useKilometers {
            return DistanceFormatterHelper.string(for: totalMiles, useKilometers: true)
        } else if showThousandsOfMiles {
            let thousands = totalMiles / 1000
            return String(format: "%.1fK mi", thousands)
        } else {
            return DistanceFormatterHelper.string(for: totalMiles, useKilometers: false)
        }
    }
    
    var totalDistanceLabel: String {
        if useKilometers { return "Total Kilometers Driven" }
        else { return "Total Miles Driven" }
    }
    
    var totalDriveTime: TimeInterval {
        filteredTripsByCategory.reduce(0) { $0 + $1.endTime.timeIntervalSince($1.startTime) }
    }
    
    var totalDriveTimeFormatted: String {
        let interval = Int(totalDriveTime)
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        if interval >= 3600 {
            if minutes > 0 {
                return "\(hours) hr \(minutes) min"
            } else {
                return "\(hours) hr"
            }
        } else {
            let mins = interval / 60
            return "\(mins) min"
        }
    }
    
    var dailyMileages: [DailyMileage] {
        let grouped = Dictionary(grouping: filteredTripsByCategory) { trip in
            Calendar.current.startOfDay(for: trip.startTime)
        }
        return grouped.map { date, trips in
            DailyMileage(
                date: date,
                miles: trips.reduce(0) { $0 + $1.distance },
                duration: trips.reduce(0) { $0 + $1.endTime.timeIntervalSince($1.startTime) }
            )
        }
        .sorted { $0.date < $1.date }
    }
    
    var dailyDistances: [DailyMetric] {
        dailyMileages.map { day in
            DailyMetric(date: day.date, type: useKilometers ? "Kilometers" : "Miles", value: useKilometers ? day.miles * 1.60934 : day.miles)
        }
    }
    
    var dailyDriveTimes: [DailyMetric] {
        dailyMileages.map { day in
            DailyMetric(date: day.date, type: "Drive Minutes", value: day.duration / 60)
        }
    }
    
    var showDriveHours: Bool {
        dailyDriveTimes.contains { $0.value >= 60 }
    }
    
    var dailyDriveTimeDisplay: [DailyMetric] {
        if showDriveHours {
            return dailyDriveTimes.map { .init(date: $0.date, type: "Drive Hours", value: $0.value / 60) }
        } else {
            return dailyDriveTimes
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    // MARK: - Statistics Computed Properties
    var averageTripDistance: Double {
        guard !filteredTripsByCategory.isEmpty else { return 0 }
        return totalMiles / Double(filteredTripsByCategory.count)
    }
    
    var averageTripDuration: TimeInterval {
        guard !filteredTripsByCategory.isEmpty else { return 0 }
        return totalDriveTime / Double(filteredTripsByCategory.count)
    }
    
    var averageTripDurationFormatted: String {
        let interval = Int(averageTripDuration)
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        
        if interval >= 3600 {
            if minutes > 0 {
                return "\(hours) hr \(minutes) min"
            } else {
                return "\(hours) hr"
            }
        } else {
            return "\(minutes) min"
        }
    }
    
    var longestTrip: Trip? {
        filteredTripsByCategory.max(by: { $0.distance < $1.distance })
    }
    
    var shortestTrip: Trip? {
        filteredTripsByCategory.min(by: { $0.distance < $1.distance })
    }
    
    var body: some View {
        if tripLogProtectionEnabled && !isAuthenticated {
            VStack {
                Spacer()
                Image(systemName: "lock.shield.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.accentColor)
                    .padding(.bottom, 20)
                Text("Mileage Report Locked")
                    .font(.title)
                Text("Authenticate to view your mileage report.")
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
        } else {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading) {
                        VStack(spacing: 16) {
                            Picker("Time Filter", selection: $selectedFilter) {
                                ForEach(TimeFilter.allCases) { filter in
                                    Text(filter.rawValue).tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: selectedFilter) { newValue in
                                savedSelectedFilterRawValue = newValue.rawValue
                                if newValue == .custom {
                                    showingDateRangePicker = true
                                }
                            }
                            
                            if selectedFilter == .custom {
                                HStack {
                                    Text("Custom Range:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button(action: { showingDateRangePicker = true }) {
                                        Text("\(customStartDate, formatter: dateFormatter) - \(customEndDate, formatter: dateFormatter)")
                                            .font(.subheadline)
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                        .padding([.top, .horizontal])
                        
                        Picker("Category Filter", selection: $selectedCategory) {
                            ForEach(supportedCategories, id: \.self) { category in
                                Text(category).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal)
                        
                        Text("Showing \(filteredTripsByCategory.count) trip log\(filteredTripsByCategory.count == 1 ? "" : "s") for the selected category.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(totalDistanceLabel)
                                .font(.caption)
                            Text(totalDistanceDisplay)
                                .font(.title2)
                                .bold()
                            Text("Total Minutes Driving")
                                .font(.caption)
                                .padding(.top, 4)
                            Text(totalDriveTimeFormatted)
                                .font(.title3)
                                .bold()
                        }
                        .padding(.horizontal)
                        
                        // Statistics Card
                        if !filteredTripsByCategory.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Statistics")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                    StatCard(
                                        title: "Average Trip",
                                        value: DistanceFormatterHelper.string(for: averageTripDistance, useKilometers: useKilometers),
                                        icon: "gauge.medium"
                                    )
                                    StatCard(
                                        title: "Average Duration",
                                        value: averageTripDurationFormatted,
                                        icon: "clock"
                                    )
                                    if let longest = longestTrip {
                                        StatCard(
                                            title: "Longest Trip",
                                            value: DistanceFormatterHelper.string(for: longest.distance, useKilometers: useKilometers),
                                            icon: "arrow.up.circle"
                                        )
                                    }
                                    if let shortest = shortestTrip {
                                        StatCard(
                                            title: "Shortest Trip",
                                            value: DistanceFormatterHelper.string(for: shortest.distance, useKilometers: useKilometers),
                                            icon: "arrow.down.circle"
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical)
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Group {
                                if dailyDistances.isEmpty {
                                    Spacer()
                                    Text("No distance data to display for the selected time range.")
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity)
                                    Spacer()
                                } else {
                                    Chart(dailyDistances) { metric in
                                        BarMark(
                                            x: .value("Date", metric.date, unit: .day),
                                            y: .value("Distance", metric.value)
                                        )
                                        .foregroundStyle(Color.accentColor)
                                    }
                                    .chartXAxis {
                                        AxisMarks(values: .stride(by: .day)) { value in
                                            AxisGridLine()
                                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                        }
                                    }
                                    .chartYAxisLabel("\(useKilometers ? "Kilometers" : "Miles") Driven")
                                    .frame(height: 150)
                                    .padding(.horizontal)
                                    // Legend
                                    HStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.accentColor)
                                            .frame(width: 20, height: 10)
                                        Text("\(useKilometers ? "Kilometers" : "Miles") Driven")
                                            .font(.caption)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            Group {
                                if dailyDriveTimeDisplay.isEmpty {
                                    Spacer()
                                    Text("No drive time data to display for the selected time range.")
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity)
                                    Spacer()
                                } else {
                                    Chart(dailyDriveTimeDisplay) { metric in
                                        BarMark(
                                            x: .value("Date", metric.date, unit: .day),
                                            y: .value(showDriveHours ? "Drive Hours" : "Drive Minutes", metric.value)
                                        )
                                        .foregroundStyle(Color.orange)
                                    }
                                    .chartXAxis {
                                        AxisMarks(values: .stride(by: .day)) { value in
                                            AxisGridLine()
                                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                        }
                                    }
                                    .chartYAxisLabel(showDriveHours ? "Drive Hours" : "Drive Minutes")
                                    .frame(height: 150)
                                    .padding(.horizontal)
                                    // Legend
                                    HStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.orange)
                                            .frame(width: 20, height: 10)
                                        Text(showDriveHours ? "Drive Hours" : "Drive Minutes")
                                            .font(.caption)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        Spacer()
                    }
                    .refreshable {
                        // Trigger refresh of trip data if needed
                        // This could be extended to sync with cloud or reload data
                        try? await Task.sleep(nanoseconds: 500_000_000) // Small delay for UI feedback
                    }
                    .navigationTitle("Mileage Report")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Export") {
                                generateCSVExport()
                            }
                            .disabled(filteredTripsByCategory.isEmpty)
                        }
                    }
                }
                .onAppear {
                    if tripLogProtectionEnabled && !isAuthenticated {
                        authenticate()
                    }
                    selectedFilter = TimeFilter(rawValue: savedSelectedFilterRawValue) ?? .last7
                }
                .onChange(of: scenePhase) { newPhase in
                    if tripLogProtectionEnabled && isAuthenticated && (newPhase == .background || newPhase == .inactive) {
                        isAuthenticated = false
                        didAttemptInitialAuth = false
                        print("[MileageReportView] App moved to background/inactive, relocking the view.")
                    }
                }
                .fileExporter(
                    isPresented: $showingExportSheet,
                    document: exportDocument,
                    contentType: .commaSeparatedText,
                    defaultFilename: "mileage-report-\(selectedFilter.rawValue.replacingOccurrences(of: " ", with: "-").lowercased())"
                ) { result in
                    switch result {
                    case .success(let url):
                        print("Exported to: \(url)")
                    case .failure(let error):
                        print("Export failed: \(error)")
                    }
                }
                .sheet(isPresented: $showingDateRangePicker) {
                    NavigationView {
                        VStack(spacing: 20) {
                            DatePicker("Start Date", selection: $customStartDate, displayedComponents: .date)
                            DatePicker("End Date", selection: $customEndDate, displayedComponents: .date)
                            Spacer()
                        }
                        .padding()
                        .navigationTitle("Custom Date Range")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Cancel") {
                                    showingDateRangePicker = false
                                    selectedFilter = .last7 // Reset to default
                                }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingDateRangePicker = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        let policy: LAPolicy = tripLogProtectionMethod == "biometric" ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        if context.canEvaluatePolicy(policy, error: &error) {
            context.evaluatePolicy(policy, localizedReason: "Unlock your mileage report") { success, evalError in
                DispatchQueue.main.async {
                    if success {
                        isAuthenticated = true
                        showAuthError = false
                        // Unlocking now only dismisses the lock overlay, does not dismiss the view or navigate elsewhere.
                        print("[MileageReportView] Face ID unlock successful. Lock overlay dismissed, staying on report page.")
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
    
    private func generateCSVExport() {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        let distanceUnit = useKilometers ? "km" : "mi"
        let conversionFactor = useKilometers ? 1.60934 : 1.0
        
        var csvContent = "Date,Start Time,End Time,Category,Distance (\(distanceUnit)),Duration (minutes),Start Location,End Location\n"
        
        for trip in filteredTripsByCategory.sorted(by: { $0.startTime < $1.startTime }) {
            let startTime = formatter.string(from: trip.startTime)
            let endTime = formatter.string(from: trip.endTime)
            let distance = String(format: "%.2f", trip.distance * conversionFactor)
            let duration = String(format: "%.1f", trip.endTime.timeIntervalSince(trip.startTime) / 60)
            
            let startLocation: String
            if let startCoord = trip.startCoordinate {
                startLocation = "\(String(format: "%.6f", startCoord.latitude));\(String(format: "%.6f", startCoord.longitude))"
            } else {
                startLocation = "Unknown"
            }
            
            let endLocation: String
            if let endCoord = trip.endCoordinate {
                endLocation = "\(String(format: "%.6f", endCoord.latitude));\(String(format: "%.6f", endCoord.longitude))"
            } else {
                endLocation = "Unknown"
            }
            
            csvContent += "\(formatter.string(from: trip.startTime)),\(startTime),\(endTime),\(trip.reason),\(distance),\(duration),\(startLocation),\(endLocation)\n"
        }
        
        // Add summary row
        csvContent += "\nSummary:\n"
        csvContent += "Total Distance (\(distanceUnit)),\(String(format: "%.2f", totalMiles * conversionFactor))\n"
        csvContent += "Total Drive Time,\(totalDriveTimeFormatted)\n"
        csvContent += "Trip Count,\(filteredTripsByCategory.count)\n"
        csvContent += "Filter Applied,\(selectedFilter.rawValue)\n"
        csvContent += "Category Filter,\(selectedCategory)\n"
        
        exportDocument = CSVDocument(text: csvContent)
        showingExportSheet = true
    }
    
    struct StatCard: View {
        let title: String
        let value: String
        let icon: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Spacer()
                }
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .bold()
            }
            .padding(12)
            .background(.regularMaterial)
            .cornerRadius(8)
        }
    }
}

#Preview("Mileage Report") {
    MileageReportView()
        .environmentObject(TripManager())
}
