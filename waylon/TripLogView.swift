
import SwiftUI
import MapKit
import UniformTypeIdentifiers

struct TripLogView: View {
    @EnvironmentObject var tripManager: TripManager
    @State private var expandedTripID: UUID? = nil
    @State private var editingTrip: Trip? = nil
    @State private var showShareSheet = false
    @State private var exportURL: URL? = nil

    var body: some View {
        List {
            ForEach(tripManager.trips) { trip in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trip Start: \(trip.startTime.formatted(date: .abbreviated, time: .shortened))")
                        .font(.headline)
                    Text("Trip End: \(trip.endTime.formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline)
                    Text("Distance: \(trip.distance, specifier: "%.2f") miles")
                        
                    if !trip.notes.isEmpty {
                        Text("Notes: \(trip.notes)")
                            .italic()
                    }
                        
                    if !trip.pay.isEmpty {
                        Text("Pay: \(trip.pay)")
                            .bold()
                    }
                        
                    HStack {
                        Button(expandedTripID == trip.id ? "Hide Map" : "Show Map") {
                            expandedTripID = expandedTripID == trip.id ? nil : trip.id
                        }
                        .buttonStyle(.borderless)

                        Spacer()

                        Button("Edit") {
                            editingTrip = trip
                        }
                        .buttonStyle(.borderless)
                    }
                        
                    if expandedTripID == trip.id {
                        TripSummaryMap(trip: trip)
                            .frame(height: 300)
                    }
                }
                .padding(.vertical, 5)
            }
            .onDelete(perform: deleteTrip)
        }
        .navigationTitle("Trip Log")
        .toolbar {
            Button("Export CSV") {
                exportTripLogsToCSV()
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
            }
        }
    }

    func deleteTrip(at offsets: IndexSet) {
        tripManager.deleteTrip(at: offsets)
    }

    func exportTripLogsToCSV() {
        let header = "Start Time,End Time,Distance (miles),Notes,Pay\n"
        let rows = tripManager.trips.map { trip in
            "\(trip.startTime),\(trip.endTime),\(trip.distance),\(trip.notes),\(trip.pay)"
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
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
