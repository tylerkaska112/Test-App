import SwiftUI
import MapKit

struct AddressSearchView: View {
    @StateObject private var searchCompleter = AddressSearchCompleter()
    @State private var searchText = ""
    @State private var selectedCompletion: MKLocalSearchCompletion?
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SearchBar(
                    text: $searchText,
                    isFocused: $isSearchFocused,
                    onSearchTextChanged: { query in
                        searchCompleter.updateQuery(query)
                    }
                )
                .padding(.vertical, 8)
                
                Divider()
                
                ZStack {
                    if searchText.isEmpty {
                        EmptyStateView()
                    } else if searchCompleter.isSearching {
                        ProgressView("Searching...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else if let errorMessage = searchCompleter.errorMessage {
                        ErrorView(message: errorMessage) {
                            searchCompleter.updateQuery(searchText)
                        }
                    } else if searchCompleter.hasNoResults {
                        NoResultsView(searchQuery: searchText)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(searchCompleter.suggestions, id: \.self) { completion in
                                    AddressRow(
                                        completion: completion,
                                        searchText: searchText
                                    ) {
                                        selectedCompletion = completion
                                        searchText = completion.title
                                        isSearchFocused = false
                                        // Handle selection - could navigate or dismiss
                                    }
                                    
                                    if completion != searchCompleter.suggestions.last {
                                        Divider()
                                            .padding(.leading, 16)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !searchText.isEmpty {
                        Button("Cancel") {
                            searchText = ""
                            isSearchFocused = false
                            searchCompleter.updateQuery("")
                        }
                        .font(.body)
                    }
                }
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onSearchTextChanged: (String) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.body)
                
                TextField("Enter address or place", text: $text)
                    .focused(isFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .onChange(of: text) { _, newValue in
                        onSearchTextChanged(newValue)
                    }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                        onSearchTextChanged("")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.body)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
    }
}

struct AddressRow: View {
    let completion: MKLocalSearchCompletion
    let searchText: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .foregroundColor(.blue)
                    .font(.title3)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(highlightedTitle)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if !completion.subtitle.isEmpty {
                        Text(completion.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconName: String {
        // Determine icon based on completion type
        if completion.title.lowercased().contains("restaurant") ||
           completion.title.lowercased().contains("cafe") {
            return "fork.knife"
        } else if completion.subtitle.isEmpty {
            return "mappin.circle.fill"
        } else {
            return "mappin.and.ellipse"
        }
    }
    
    private var highlightedTitle: AttributedString {
        var attributedString = AttributedString(completion.title)
        // You can add text highlighting here if needed
        return attributedString
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("Search for an Address")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Enter a street address, city, or place name to find locations")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct NoResultsView: View {
    let searchQuery: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No Results Found")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("No locations match \"\(searchQuery)\"")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Text("Try adjusting your search or check the spelling")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 50))
            
            Text("Something Went Wrong")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Button(action: onRetry) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    AddressSearchView()
}
