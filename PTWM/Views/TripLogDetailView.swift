// TripLogDetailView.swift
// Displays all details about a single trip log in a readable format.

import SwiftUI
import MapKit

struct TripLogDetailView: View {
    @State var trip: Trip
    @Environment(\.dismiss) private var dismiss
    @AppStorage("useKilometers") private var useKilometers: Bool = false
    @AppStorage("gasPricePerGallon") private var gasPricePerGallon: Double = 3.99
    @EnvironmentObject var tripManager: TripManager
    @State private var editingTrip: Trip?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(trip.startTime.formatted(date: .abbreviated, time: .shortened))
                        .font(.headline)
                    
                    if trip.routeCoordinates.count >= 2 {
                        TripSummaryMap(trip: trip)
                            .frame(height: 300)
                            .cornerRadius(12)
                            .padding(.vertical, 6)
                    }
                    
                    if !trip.reason.isEmpty {
                        Text("Category: \(trip.reason)")
                            .font(.subheadline)
                    }
                    if !trip.notes.isEmpty {
                        Text("Name: \(trip.notes)")
                            .font(.subheadline)
                    }
                    Divider()
                    Group {
                        Text("Trip End: \(trip.endTime.formatted(date: .abbreviated, time: .shortened))")
                        Text("Distance: \(DistanceFormatterHelper.string(for: trip.distance, useKilometers: useKilometers))")
                        if let fuelGallons = fuelUsedForTrip {
                            Text("Estimated Fuel Used: " + String(format: "%.2f gallons", fuelGallons))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        if let fuelGallons = fuelUsedForTrip, gasPricePerGallon > 0 {
                            let cost = fuelGallons * gasPricePerGallon
                            Text(String(format: "Estimated Fuel Cost: $%.2f", cost))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Text("Drive Duration: \(formattedDuration(from: trip.startTime, to: trip.endTime))")
                        if let avgSpeed = trip.averageSpeed {
                            Text("Avg Speed: \(AverageSpeedFormatter.string(forMetersPerSecond: avgSpeed, useKilometers: useKilometers))")
                        }
                        if trip.isRecovered {
                            Text("Recovered after app termination")
                                .foregroundColor(.orange)
                        }
                        if !trip.pay.isEmpty {
                            Text("Pay: \(trip.pay)")
                        }
                    }
                    if !trip.photoURLs.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Photos:")
                                .font(.headline)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(trip.photoURLs, id: \.self) { url in
                                        if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                                            Image(uiImage: img)
                                                .resizable()
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if !trip.audioNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Audio Notes:")
                                .font(.headline)
                            ForEach(trip.audioNotes, id: \.self) { url in
                                Text(url.lastPathComponent)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Trip Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { editingTrip = trip }) {
                        Image(systemName: "pencil")
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
        }
    }

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

extension Array where Element == CodableCoordinate {
    var clCoordinates: [CLLocationCoordinate2D] {
        map { $0.clCoordinate }
    }
}
