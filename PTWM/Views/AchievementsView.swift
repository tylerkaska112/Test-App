import SwiftUI

// MARK: - Models

struct AchievementBadge: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    let achieved: Bool
    let description: String
    let currentValue: Double
    let targetValue: Double
    let unlockedDate: Date?
    let category: AchievementCategory
    let valueFormatter: (Double) -> String
    
    // Backward-compatible initializer (without id and category)
    init(title: String, systemImage: String, achieved: Bool, description: String,
         currentValue: Double, targetValue: Double, unlockedDate: Date?,
         valueFormatter: @escaping (Double) -> String) {
        self.id = title.replacingOccurrences(of: " ", with: "_").lowercased()
        self.title = title
        self.systemImage = systemImage
        self.achieved = achieved
        self.description = description
        self.currentValue = currentValue
        self.targetValue = targetValue
        self.unlockedDate = unlockedDate
        self.category = .special // Default category
        self.valueFormatter = valueFormatter
    }
    
    // Full initializer (with id and category)
    init(id: String, title: String, systemImage: String, achieved: Bool, description: String,
         currentValue: Double, targetValue: Double, unlockedDate: Date?,
         category: AchievementCategory, valueFormatter: @escaping (Double) -> String) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.achieved = achieved
        self.description = description
        self.currentValue = currentValue
        self.targetValue = targetValue
        self.unlockedDate = unlockedDate
        self.category = category
        self.valueFormatter = valueFormatter
    }
    
    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(currentValue / targetValue, 1.0)
    }
    
    var remainingValue: Double {
        max(targetValue - currentValue, 0)
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AchievementBadge, rhs: AchievementBadge) -> Bool {
        lhs.id == rhs.id
    }
}

enum AchievementCategory: String, CaseIterable {
    case mileage = "Mileage"
    case time = "Time"
    case streak = "Streak"
    case special = "Special"
    
    var systemImage: String {
        switch self {
        case .mileage: return "car.fill"
        case .time: return "clock.fill"
        case .streak: return "flame.fill"
        case .special: return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .mileage: return .blue
        case .time: return .green
        case .streak: return .orange
        case .special: return .purple
        }
    }
}

// MARK: - Achievement Manager

@MainActor
class AchievementManager: ObservableObject {
    private let tripManager: TripManager
    private let userDefaults: UserDefaults
    
    init(tripManager: TripManager, userDefaults: UserDefaults = .standard) {
        self.tripManager = tripManager
        self.userDefaults = userDefaults
    }
    
    // MARK: - Unlock Date Storage
    
    func getUnlockDate(for achievementId: String) -> Date? {
        userDefaults.object(forKey: "unlock_\(achievementId)") as? Date
    }
    
    func setUnlockDate(_ date: Date, for achievementId: String) {
        userDefaults.set(date, forKey: "unlock_\(achievementId)")
    }
    
    // MARK: - Achievement Generators
    
    func generateMileageAchievements(lifetimeMiles: Double, useKilometers: Bool) -> [AchievementBadge] {
        let thresholds: [(Double, String, String)] = [
            (1, "figure.walk", "1 Mile"),
            (5, "car.fill", "5 Miles"),
            (25, "rosette", "25 Miles"),
            (100, "flag.checkered", "100 Miles"),
            (250, "star.fill", "250 Miles"),
            (500, "paperplane.fill", "500 Miles"),
            (1000, "car.2.fill", "1,000 Miles"),
            (2500, "speedometer", "2,500 Miles"),
            (5000, "trophy.fill", "5,000 Miles"),
            (10000, "crown.fill", "10,000 Miles")
        ]
        
        let distanceValue = useKilometers ? lifetimeMiles * 1.60934 : lifetimeMiles
        let unit = useKilometers ? "km" : "miles"
        
        return thresholds.map { miles, symbol, baseTitle in
            let threshold = useKilometers ? miles * 1.60934 : miles
            let title = useKilometers ? formatKilometers(threshold) : baseTitle
            let achievementId = "mileage_\(miles)"
            let unlocked = distanceValue >= threshold
            
            return AchievementBadge(
                id: achievementId,
                title: title,
                systemImage: symbol,
                achieved: unlocked,
                description: "Travel a total lifetime distance of \(title.lowercased()).",
                currentValue: distanceValue,
                targetValue: threshold,
                unlockedDate: unlocked ? getUnlockDate(for: achievementId) : nil,
                category: .mileage,
                valueFormatter: { String(format: "%.1f \(unit)", $0) }
            )
        }
    }
    
    func generateStreakAchievements(longestStreak: Int) -> [AchievementBadge] {
        let thresholds: [(Int, String, String, String)] = [
            (3, "flame", "3 Day Streak", "Complete trips on 3 consecutive days."),
            (7, "flame.fill", "1 Week Streak", "Complete trips for 7 days in a row."),
            (14, "calendar", "2 Week Streak", "Maintain a 14-day trip streak."),
            (30, "calendar.badge.plus", "1 Month Streak", "Keep your streak alive for 30 days."),
            (60, "trophy", "2 Month Streak", "An impressive 60-day streak!"),
            (100, "crown", "100 Day Streak", "Complete trips for 100 consecutive days."),
            (365, "star.circle", "1 Year Streak", "A full year of daily trips!")
        ]
        
        return thresholds.map { threshold, symbol, title, desc in
            let achievementId = "streak_\(threshold)"
            let unlocked = longestStreak >= threshold
            
            return AchievementBadge(
                id: achievementId,
                title: title,
                systemImage: symbol,
                achieved: unlocked,
                description: desc,
                currentValue: Double(longestStreak),
                targetValue: Double(threshold),
                unlockedDate: unlocked ? getUnlockDate(for: achievementId) : nil,
                category: .streak,
                valueFormatter: { "\(Int($0)) days" }
            )
        }
    }
    
    func generateTimeAchievements(lifetimeHours: Double) -> [AchievementBadge] {
        let thresholds: [(Double, String, String, String)] = [
            (5.0/60.0, "timer", "5 Minutes", "Spend 5 minutes driving."),
            (30.0/60.0, "timer", "30 Minutes", "Drive for a total of 30 minutes."),
            (1, "clock", "1 Hour", "Accumulate 1 hour of drive time."),
            (2, "clock.fill", "2 Hours", "Reach 2 hours of total drive time."),
            (4, "hourglass", "4 Hours", "Drive for a total of 4 hours."),
            (12, "hourglass.tophalf.filled", "12 Hours", "Spend 12 hours on the road."),
            (24, "hourglass.bottomhalf.filled", "24 Hours", "Complete a full day of driving!"),
            (30, "clock.arrow.2.circlepath", "30 Hours", "Accumulate 30 hours behind the wheel."),
            (48, "alarm", "48 Hours", "Reach 48 hours of drive time."),
            (100, "stopwatch", "100 Hours", "An incredible 100 hours of driving!")
        ]
        
        return thresholds.map { threshold, symbol, title, desc in
            let achievementId = "time_\(threshold)"
            let unlocked = lifetimeHours >= threshold
            
            return AchievementBadge(
                id: achievementId,
                title: title,
                systemImage: symbol,
                achieved: unlocked,
                description: desc,
                currentValue: lifetimeHours,
                targetValue: threshold,
                unlockedDate: unlocked ? getUnlockDate(for: achievementId) : nil,
                category: .time,
                valueFormatter: { String(format: "%.1f hours", $0) }
            )
        }
    }
    
    func generateSpecialAchievements(trips: [Trip]) -> [AchievementBadge] {
        let totalTrips = trips.count
        let recoveredTrips = trips.filter { $0.isRecovered }.count
        let tripsWithNotes = trips.filter { !$0.notes.isEmpty }.count
        let tripsWithPhotos = trips.filter { !$0.photoURLs.isEmpty }.count
        let tripsWithAudio = trips.filter { !$0.audioNotes.isEmpty }.count
        
        var achievements: [AchievementBadge] = []
        
        // Trip count achievements
        let tripThresholds: [(Int, String, String, String)] = [
            (1, "car", "First Trip", "Complete your very first trip."),
            (10, "car.fill", "10 Trips", "Reach 10 total trips."),
            (50, "car.2.fill", "50 Trips", "Complete 50 trips in total."),
            (100, "bus.fill", "Century Club", "An impressive milestone of 100 trips!"),
            (250, "airplane", "Frequent Traveler", "You've completed 250 trips."),
            (500, "ferry.fill", "Road Warrior", "500 trips completed!"),
            (1000, "train.side.front.car", "Travel Master", "An incredible 1,000 trips!")
        ]
        
        achievements += tripThresholds.map { threshold, symbol, title, desc in
            let achievementId = "trips_\(threshold)"
            let unlocked = totalTrips >= threshold
            
            return AchievementBadge(
                id: achievementId,
                title: title,
                systemImage: symbol,
                achieved: unlocked,
                description: desc,
                currentValue: Double(totalTrips),
                targetValue: Double(threshold),
                unlockedDate: unlocked ? getUnlockDate(for: achievementId) : nil,
                category: .special,
                valueFormatter: { "\(Int($0)) trips" }
            )
        }
        
        // Content achievements
        let contentAchievements: [(Int, String, String, String, String, Int)] = [
            (10, "storyteller", "Storyteller", "text.bubble", "Add notes to 10 different trips.", tripsWithNotes),
            (5, "photographer", "Photographer", "camera", "Add photos to 5 different trips.", tripsWithPhotos),
            (3, "voice_logger", "Voice Logger", "mic", "Record audio notes for 3 different trips.", tripsWithAudio),
            (1, "survivor", "Survivor", "heart.fill", "Successfully recover at least one trip from the trash.", recoveredTrips)
        ]
        
        achievements += contentAchievements.map { threshold, id, title, symbol, desc, currentCount in
            let unlocked = currentCount >= threshold
            
            return AchievementBadge(
                id: id,
                title: title,
                systemImage: symbol,
                achieved: unlocked,
                description: desc,
                currentValue: Double(currentCount),
                targetValue: Double(threshold),
                unlockedDate: unlocked ? getUnlockDate(for: id) : nil,
                category: .special,
                valueFormatter: { value in
                    let type = id == "survivor" ? "recovered" : id == "storyteller" ? "notes" : id == "photographer" ? "photos" : "audio"
                    return "\(Int(value)) trips with \(type)"
                }
            )
        }
        
        return achievements
    }
    
    // MARK: - Helpers
    
    private func formatKilometers(_ km: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        let kmString = formatter.string(from: NSNumber(value: km)) ?? String(format: "%.1f", km)
        return "\(kmString) Km"
    }
}

// MARK: - Main View

struct AchievementsView: View {
    @EnvironmentObject var tripManager: TripManager
    @AppStorage("dailyStreak") private var dailyStreak: Int = 0
    @AppStorage("longestStreak") private var longestStreak: Int = 0
    @AppStorage("lifetimeMiles") private var lifetimeMiles: Double = 0.0
    @AppStorage("useKilometers") private var useKilometers: Bool = false
    
    @StateObject private var achievementManager: AchievementManager
    @State private var expandedCategories: Set<AchievementCategory> = []
    @State private var searchText = ""
    @State private var showOnlyUnlocked = false
    @State private var selectedAchievement: AchievementBadge?
    @State private var timeUntilMidnight: TimeInterval = 0
    @State private var timer: Timer?
    
    init() {
        // This needs to be initialized properly with the actual tripManager
        // For now, we'll use a placeholder approach
        let manager = AchievementManager(tripManager: TripManager())
        _achievementManager = StateObject(wrappedValue: manager)
    }
    
    // MARK: - Computed Properties
    
    private var allAchievements: [AchievementBadge] {
        achievementManager.generateMileageAchievements(lifetimeMiles: lifetimeMiles, useKilometers: useKilometers) +
        achievementManager.generateStreakAchievements(longestStreak: longestStreak) +
        achievementManager.generateTimeAchievements(lifetimeHours: tripManager.lifetimeDriveHours) +
        achievementManager.generateSpecialAchievements(trips: tripManager.trips)
    }
    
    private var filteredAchievements: [AchievementBadge] {
        allAchievements.filter { achievement in
            let matchesSearch = searchText.isEmpty ||
                achievement.title.localizedCaseInsensitiveContains(searchText) ||
                achievement.description.localizedCaseInsensitiveContains(searchText)
            let matchesFilter = !showOnlyUnlocked || achievement.achieved
            return matchesSearch && matchesFilter
        }
    }
    
    private var achievementStats: (unlocked: Int, total: Int, percentage: Int) {
        let unlocked = allAchievements.filter(\.achieved).count
        let total = allAchievements.count
        let percentage = total > 0 ? Int(Double(unlocked) / Double(total) * 100) : 0
        return (unlocked, total, percentage)
    }
    
    private var formattedTimeUntilMidnight: String {
        let totalSeconds = Int(timeUntilMidnight)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    achievementSummarySection
                    Divider()
                    dailyStreakSection
                    Divider()
                    
                    ForEach(AchievementCategory.allCases, id: \.self) { category in
                        categorySection(for: category)
                        if category != AchievementCategory.allCases.last {
                            Divider()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Achievements")
            .searchable(text: $searchText, prompt: "Search achievements...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showOnlyUnlocked.toggle() }) {
                        Image(systemName: showOnlyUnlocked ? "star.fill" : "star")
                            .foregroundColor(showOnlyUnlocked ? .yellow : .accentColor)
                    }
                }
            }
            .overlay(achievementNotificationOverlay)
            .sheet(item: $selectedAchievement) { achievement in
                AchievementDetailView(achievement: achievement)
            }
            .onAppear(perform: setupTimer)
            .onDisappear(perform: cleanupTimer)
        }
    }
    
    // MARK: - View Components
    
    private var achievementSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievement Progress")
                .font(.headline)
            
            let stats = achievementStats
            
            HStack(spacing: 12) {
                StatCard(label: "Unlocked", value: "\(stats.unlocked)", accentColor: .green)
                StatCard(label: "Total", value: "\(stats.total)", accentColor: .blue)
                StatCard(label: "Progress", value: "\(stats.percentage)%", accentColor: .purple)
            }
            
            ProgressView(value: Double(stats.unlocked), total: Double(stats.total)) {
                Text("Overall Progress")
                    .font(.caption)
            }
            .tint(.purple)
        }
    }
    
    private var dailyStreakSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Streak")
                .font(.headline)
            
            HStack(spacing: 12) {
                StatCard(label: "Current", value: "\(dailyStreak)", accentColor: .orange)
                StatCard(label: "Longest", value: "\(longestStreak)", accentColor: .red)
            }
            
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text("Next streak opportunity in \(formattedTimeUntilMidnight)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func categorySection(for category: AchievementCategory) -> some View {
        let categoryAchievements = filteredAchievements.filter { $0.category == category }
        let isExpanded = expandedCategories.contains(category)
        
        return DisclosureGroup(
            isExpanded: Binding(
                get: { isExpanded },
                set: { newValue in
                    if newValue {
                        expandedCategories.insert(category)
                    } else {
                        expandedCategories.remove(category)
                    }
                }
            ),
            content: {
                if isExpanded && !categoryAchievements.isEmpty {
                    VStack(spacing: 16) {
                        categoryProgressView(for: category, achievements: categoryAchievements)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 16)], spacing: 16) {
                            ForEach(categoryAchievements) { badge in
                                AchievementBadgeView(badge: badge, accentColor: category.color)
                                    .onTapGesture {
                                        selectedAchievement = badge
                                    }
                            }
                        }
                        
                        categorySummaryView(for: category)
                    }
                    .padding(.top, 8)
                }
            },
            label: {
                DisclosureGroupLabel(
                    title: category.rawValue,
                    systemImage: category.systemImage,
                    count: categoryAchievements.filter(\.achieved).count,
                    total: categoryAchievements.count,
                    isExpanded: isExpanded
                )
            }
        )
    }
    
    @ViewBuilder
    private func categoryProgressView(for category: AchievementCategory, achievements: [AchievementBadge]) -> some View {
        if let nextAchievement = achievements.first(where: { !$0.achieved }) {
            ProgressView(value: nextAchievement.progress) {
                Text("Progress to \(nextAchievement.title)")
                    .font(.caption)
            } currentValueLabel: {
                Text("\(Int(nextAchievement.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .tint(category.color)
        }
    }
    
    @ViewBuilder
    private func categorySummaryView(for category: AchievementCategory) -> some View {
        switch category {
        case .mileage:
            let value = useKilometers ? lifetimeMiles * 1.60934 : lifetimeMiles
            let unit = useKilometers ? "km" : "miles"
            StatCard(
                label: "Lifetime \(unit.capitalized)",
                value: String(format: "%.1f", value),
                accentColor: category.color
            )
            
        case .time:
            StatCard(
                label: "Lifetime Hours",
                value: String(format: "%.1f", tripManager.lifetimeDriveHours),
                accentColor: category.color
            )
            
        case .special:
            HStack(spacing: 12) {
                StatCard(
                    label: "Total Trips",
                    value: "\(tripManager.trips.count)",
                    accentColor: category.color
                )
                StatCard(
                    label: "With Notes",
                    value: "\(tripManager.trips.filter { !$0.notes.isEmpty }.count)",
                    accentColor: category.color
                )
            }
            
        case .streak:
            EmptyView()
        }
    }
    
    private var achievementNotificationOverlay: some View {
        Group {
            if let achievement = tripManager.unlockedAchievement {
                AchievementNotificationView(achievement: achievement) {
                    tripManager.unlockedAchievement = nil
                }
                .zIndex(1)
            }
        }
    }
    
    // MARK: - Timer Management
    
    private func setupTimer() {
        updateTimeUntilMidnight()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateTimeUntilMidnight()
        }
    }
    
    private func cleanupTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTimeUntilMidnight() {
        let calendar = Calendar.current
        let now = Date()
        if let nextMidnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .strict,
            direction: .forward
        ) {
            timeUntilMidnight = nextMidnight.timeIntervalSince(now)
        } else {
            timeUntilMidnight = 0
        }
    }
}

// MARK: - Supporting Views

struct AchievementBadgeView: View {
    let badge: AchievementBadge
    let accentColor: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(badge.achieved ? accentColor.opacity(0.2) : Color(.systemGray6))
                    .frame(width: 60, height: 60)
                
                Image(systemName: badge.systemImage)
                    .font(.system(size: 28))
                    .foregroundColor(badge.achieved ? accentColor : .gray)
                
                if badge.achieved {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                        .background(Circle().fill(Color(.systemBackground)).scaleEffect(0.8))
                        .offset(x: 20, y: -20)
                }
            }
            
            Text(badge.title)
                .font(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundColor(badge.achieved ? .primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            if !badge.achieved {
                ProgressView(value: badge.progress)
                    .tint(accentColor)
                    .scaleEffect(0.8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(badge.achieved ? accentColor.opacity(0.3) : Color(.systemGray4), lineWidth: 1)
        )
    }
}

struct DisclosureGroupLabel: View {
    let title: String
    let systemImage: String
    let count: Int
    let total: Int
    let isExpanded: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            Text(title)
                .font(.headline)
            
            Text("(\(count)/\(total))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

struct AchievementNotificationView: View {
    let achievement: AchievementBadge
    let onDismiss: () -> Void
    
    @State private var isShowing = false
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: achievement.systemImage)
                        .font(.system(size: 32))
                        .foregroundColor(.yellow)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text("Achievement Unlocked!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(achievement.title)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(achievement.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.yellow.opacity(0.5), lineWidth: 2)
            )
            .padding(.horizontal)
            .padding(.bottom, 100)
            .offset(y: isShowing ? 0 : 200)
            .opacity(isShowing ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isShowing = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isShowing = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }
}

struct AchievementDetailView: View {
    let achievement: AchievementBadge
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Achievement Icon
                    ZStack {
                        Circle()
                            .fill(achievement.achieved ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.1))
                            .frame(width: 140, height: 140)
                        
                        Circle()
                            .stroke(achievement.achieved ? Color.yellow : Color.gray, lineWidth: 3)
                            .frame(width: 140, height: 140)
                        
                        Image(systemName: achievement.systemImage)
                            .font(.system(size: 60, weight: .medium))
                            .foregroundColor(achievement.achieved ? .yellow : .gray)
                        
                        if achievement.achieved {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.green)
                                .background(Circle().fill(Color(.systemBackground)).scaleEffect(0.8))
                                .offset(x: 45, y: -45)
                        }
                    }
                    
                    // Title
                    Text(achievement.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    // Status Badge
                    HStack(spacing: 6) {
                        Image(systemName: achievement.achieved ? "checkmark.circle.fill" : "lock.circle.fill")
                        Text(achievement.achieved ? "Unlocked" : "Locked")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(achievement.achieved ? .green : .orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(achievement.achieved ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    )
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Description")
                            .font(.headline)
                        Text(achievement.description)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Unlock Date or Progress
                    if achievement.achieved {
                        if let unlockDate = achievement.unlockedDate {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Unlocked On")
                                    .font(.headline)
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.blue)
                                    Text(unlockDate, style: .date)
                                    Text("at")
                                        .foregroundColor(.secondary)
                                    Text(unlockDate, style: .time)
                                }
                                .font(.body)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Progress")
                                .font(.headline)
                            
                            HStack {
                                Text(achievement.valueFormatter(achievement.currentValue))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                Text("of")
                                    .foregroundColor(.secondary)
                                Text(achievement.valueFormatter(achievement.targetValue))
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }
                            
                            ProgressView(value: achievement.progress)
                                .tint(.blue)
                            
                            Text("\(achievement.valueFormatter(achievement.remainingValue)) remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationTitle("Achievement Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accentColor.opacity(0.4), lineWidth: 1)
        )
        .overlay(
            VStack { Spacer(minLength: 0) }
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    Rectangle()
                        .fill(accentColor)
                        .frame(width: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    , alignment: .leading
                )
        )
    }
}
