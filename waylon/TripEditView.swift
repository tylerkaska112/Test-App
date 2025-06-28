//
//  TripEditView.swift
//  waylon
//
//  Created by tyler kaska on 6/26/25.
//

import SwiftUI

struct TripEditView: View {
    @Environment(\.dismiss) var dismiss
    @State var trip: Trip
    var onSave: (Trip) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Notes")) {
                    TextField("Notes", text: $trip.notes)
                }
                
                Section(header: Text("Pay")) {
                    TextField("Pay", text: $trip.pay)
                }
            }
            .navigationTitle("Edit Trip")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(trip)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
