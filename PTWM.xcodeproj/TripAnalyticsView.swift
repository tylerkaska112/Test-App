import SwiftUI
import Charts

struct TripAnalyticsView: View {
    let trips: [Trip]
    @State private var selectedTimeframe: Timeframe = .month
    
    enum Timeframe: String, CaseIterable {
        case week = "Week"
        case month = "Month" 
        case year = "Year"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Timeframe Picker
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        ForEach(Timeframe.allCases, id: \.self) { timeframe in
                            Text(timeframe.rawValue).tag(timeframe)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Distance Over Time Chart
                    GlassCard {
                        VStack(alignment: .leading) {
                            Text("Distance Traveled")
                                .font(.headline)
                                .padding(.bottom)
                            
                            Chart(filteredTrips) { trip in
                                LineMark(
                                    x: .value("Date", trip.startTime),
                                    y: .value("Distance", trip.distance)
                                )
                                .foregroundStyle(.blue)
                                
                                AreaMark(
                                    x: .value("Date", trip.startTime),
                                    y: .value("Distance", trip.distance)
                                )
                                .foregroundStyle(.blue.opacity(0.2))
                            }
                            .frame(height: 200)
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 5))
                            }
                        }
                    }
                    
                    // Trip Categories Pie Chart
                    GlassCard {
                        VStack(alignment: .leading) {
                            Text("Trip Categories")
                                .font(.headline)
                                .padding(.bottom)
                            
                            Chart(tripsByCategory, id: \.category) { data in
                                SectorMark(
                                    angle: .value("Count", data.count),
                                    innerRadius: .ratio(0.5),
                                    angularInset: 2
                                )
                                .foregroundStyle(by: .value("Category", data.category.rawValue))
                                .annotation(position: .overlay) {
                                    Text("\(data.count)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(height: 200)
                        }
                    }
                    
                    // Weekly Summary Cards
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        TripStatsCard(
                            title: "Total Distance",
                            value: "\(Int(totalDistance)) mi",
                            icon: "location.fill"
                        )
                        
                        TripStatsCard(
                            title: "Total Trips",
                            value: "\(filteredTrips.count)",
                            icon: "car.fill"
                        )
                        
                        TripStatsCard(
                            title: "Avg Trip Length", 
                            value: "\(Int(averageTripDistance)) mi",
                            icon: "chart.line.uptrend.xyaxis"
                        )
                        
                        TripStatsCard(
                            title: "Business Trips",
                            value: "\(businessTripCount)",
                            icon: "briefcase.fill"
                        )
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Computed Properties
    
    var filteredTrips: [Trip] {
        let calendar = Calendar.current
        let now = Date()
        
        let startDate: Date
        switch selectedTimeframe {
        case .week:
            startDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
        
        return trips.filter { $0.startTime >= startDate }
    }
    
    var tripsByCategory: [(category: TripCategory, count: Int)] {
        let grouped = Dictionary(grouping: filteredTrips, by: \.category)
        return grouped.map { (category: $0.key, count: $0.value.count) }
    }
    
    var totalDistance: Double {
        filteredTrips.reduce(0) { $0 + $1.distance }
    }
    
    var averageTripDistance: Double {
        guard !filteredTrips.isEmpty else { return 0 }
        return totalDistance / Double(filteredTrips.count)
    }
    
    var businessTripCount: Int {
        filteredTrips.filter { $0.category == .business }.count
    }
}