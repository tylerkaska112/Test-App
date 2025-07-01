import SwiftUI
import Charts


struct MileageReportView: View {
    @EnvironmentObject var tripManager: TripManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("useKilometers") private var useKilometers: Bool = false
    
    enum TimeFilter: String, CaseIterable, Identifiable {
        case last7 = "7 Days"
        case last30 = "30 Days"
        case last90 = "3 Months"
        case last365 = "Year"
        case all = "All Time"
        var id: String { self.rawValue }
    }
    
    @State private var selectedFilter: TimeFilter = .all
    
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
    
    var filteredTrips: [Trip] {
        let now = Date()
        switch selectedFilter {
        case .all:
            return tripManager.trips
        case .last7:
            guard let startDate = Calendar.current.date(byAdding: .day, value: -7, to: now) else { return tripManager.trips }
            return tripManager.trips.filter { $0.startTime >= startDate }
        case .last30:
            guard let startDate = Calendar.current.date(byAdding: .day, value: -30, to: now) else { return tripManager.trips }
            return tripManager.trips.filter { $0.startTime >= startDate }
        case .last90:
            guard let startDate = Calendar.current.date(byAdding: .day, value: -90, to: now) else { return tripManager.trips }
            return tripManager.trips.filter { $0.startTime >= startDate }
        case .last365:
            guard let startDate = Calendar.current.date(byAdding: .day, value: -365, to: now) else { return tripManager.trips }
            return tripManager.trips.filter { $0.startTime >= startDate }
        }
    }
    
    var totalMiles: Double {
        filteredTrips.reduce(0) { $0 + $1.distance }
    }
    
    var totalDriveTime: TimeInterval {
        filteredTrips.reduce(0) { $0 + $1.endTime.timeIntervalSince($1.startTime) }
    }
    
    var totalDriveTimeFormatted: String {
        let interval = Int(totalDriveTime)
        let minutes = interval / 60
        return "\(minutes) min"
    }
    
    var dailyMileages: [DailyMileage] {
        let grouped = Dictionary(grouping: filteredTrips) { trip in
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
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                Picker("Time Filter", selection: $selectedFilter) {
                    ForEach(TimeFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.top, .horizontal])
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total \(useKilometers ? "Kilometers" : "Miles") Driven")
                        .font(.caption)
                    Text(DistanceFormatterHelper.string(for: totalMiles, useKilometers: useKilometers))
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
                        if dailyDriveTimes.isEmpty {
                            Spacer()
                            Text("No drive time data to display for the selected time range.")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                            Spacer()
                        } else {
                            Chart(dailyDriveTimes) { metric in
                                BarMark(
                                    x: .value("Date", metric.date, unit: .day),
                                    y: .value("Drive Minutes", metric.value)
                                )
                                .foregroundStyle(Color.orange)
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day)) { value in
                                    AxisGridLine()
                                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                }
                            }
                            .chartYAxisLabel("Drive Minutes")
                            .frame(height: 150)
                            .padding(.horizontal)
                            // Legend
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.orange)
                                    .frame(width: 20, height: 10)
                                Text("Drive Minutes")
                                    .font(.caption)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                Spacer()
            }
            .navigationTitle("Mileage Report")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    MileageReportView().environmentObject(TripManager())
}
