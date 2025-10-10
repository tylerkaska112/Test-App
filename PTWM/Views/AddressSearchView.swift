import SwiftUI
import MapKit

struct AddressSearchView: View {
    @StateObject private var searchCompleter = AddressSearchCompleter()
    @State private var searchText = ""
    @State private var selectedCompletion: MKLocalSearchCompletion?
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText, onSearchTextChanged: { query in
                    searchCompleter.updateQuery(query)
                })
                
                if searchCompleter.isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else if let errorMessage = searchCompleter.errorMessage {
                    ErrorView(message: errorMessage) {
                        searchCompleter.updateQuery(searchText)
                    }
                } else if searchCompleter.hasNoResults && !searchText.isEmpty {
                    Text("No results found")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(searchCompleter.suggestions, id: \.self) { completion in
                        AddressRow(completion: completion) {
                            selectedCompletion = completion
                            // Handle selection - could navigate or dismiss
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Search Address")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    let onSearchTextChanged: (String) -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Enter address or place", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: text) { _, newValue in
                    onSearchTextChanged(newValue)
                }
            
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                    onSearchTextChanged("")
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }
}

struct AddressRow: View {
    let completion: MKLocalSearchCompletion
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(completion.title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                if !completion.subtitle.isEmpty {
                    Text(completion.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
                .font(.title2)
            
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Try Again", action: onRetry)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

#Preview {
    AddressSearchView()
}