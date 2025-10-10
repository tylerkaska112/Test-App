import SwiftUI

struct GlassCard: View {
    let content: AnyView
    
    init<Content: View>(@ViewBuilder content: () -> Content) {
        self.content = AnyView(content())
    }
    
    var body: some View {
        content
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

struct TripStatsCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                Spacer()
            }
        }
    }
}