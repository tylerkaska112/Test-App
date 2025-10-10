import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject var tripManager: TripManager
    @AppStorage("dailyStreak") private var dailyStreak: Int = 0
    @AppStorage("longestStreak") private var longestStreak: Int = 0
    @AppStorage("totalDriveTime") private var totalDriveTime: Double = 0.0
    @AppStorage("maxTotalMiles") private var maxTotalMiles: Double = 0.0
    @AppStorage("lifetimeMiles") private var lifetimeMiles: Double = 0.0
    @AppStorage("useKilometers") private var useKilometers: Bool = false
    @State private var showMileageBadges = false
    @State private var showTimeBadges = false
    @State private var showStreakBadges = false
    @State private var showSpecialBadges = false
    @State private var searchText = ""
    @State private var showOnlyUnlocked = false
    
    @State private var timeUntilMidnight: TimeInterval = 0
    
    // Compute current total miles from trips without mutating any state
    var currentTotalMiles: Double {
        tripManager.trips.reduce(0) { $0 + $1.distance }
    }
    
    var mileageBadgeMiles: [(Double, String)] {
        [
            (1, "1 Mile"),
            (5, "5 Miles"),
            (25, "25 Miles"),
            (100, "100 Miles"),
            (250, "250 Miles"),
            (500, "500 Miles"),
            (1000, "1,000 Miles"),
            (2500, "2,500 Miles"),
            (5000, "5,000 Miles"),
            (10000, "10,000 Miles")
        ]
    }
    var mileageBadgeSymbols: [String] {
        ["figure.walk", "car.fill", "rosette", "flag.checkered", "star.fill", "paperplane.fill", "car.2.fill", "speedometer", "trophy.fill", "crown.fill"]
    }
    var mileageThresholds: [(Double, String, String)] {
        if useKilometers {
            return mileageBadgeMiles.enumerated().map { (i, tuple) in
                let (miles, _) = tuple
                let km = miles * 1.60934
                let numberFormatter = NumberFormatter()
                numberFormatter.numberStyle = .decimal
                numberFormatter.maximumFractionDigits = 1
                let kmString = numberFormatter.string(from: NSNumber(value: km)) ?? String(format: "%.1f", km)
                return (km, mileageBadgeSymbols[i], "\(kmString) Km")
            }
        } else {
            return mileageBadgeMiles.enumerated().map { (i, tuple) in
                let (miles, label) = tuple
                return (miles, mileageBadgeSymbols[i], label)
            }
        }
    }
    
    var mileageAchievements: [AchievementBadge] {
        // Use lifetimeMiles in miles or convert to km depending on useKilometers
        let distanceValue = useKilometers ? lifetimeMiles * 1.60934 : lifetimeMiles
        return mileageThresholds.map { threshold, symbol, title in
            AchievementBadge(title: title, systemImage: symbol, achieved: distanceValue >= threshold)
        }
    }
    
    // New computed property for streak badges
    var streakAchievements: [AchievementBadge] {
        let thresholds: [(Int, String, String)] = [
            (3, "flame", "3 Day Streak"),
            (7, "flame.fill", "1 Week Streak"),
            (14, "calendar", "2 Week Streak"),
            (30, "calendar.badge.plus", "1 Month Streak"),
            (60, "trophy", "2 Month Streak"),
            (100, "crown", "100 Day Streak"),
            (365, "star.circle", "1 Year Streak")
        ]
        
        return thresholds.map { threshold, symbol, title in
            AchievementBadge(title: title, systemImage: symbol, achieved: longestStreak >= threshold)
        }
    }
    
    // Special achievements based on trip characteristics
    var specialAchievements: [AchievementBadge] {
        let totalTrips = tripManager.trips.count
        let recoveredTrips = tripManager.trips.filter { $0.isRecovered }.count
        let tripsWithNotes = tripManager.trips.filter { !$0.notes.isEmpty }.count
        let tripsWithPhotos = tripManager.trips.filter { !$0.photoURLs.isEmpty }.count
        let tripsWithAudio = tripManager.trips.filter { !$0.audioNotes.isEmpty }.count
        
        var achievements: [AchievementBadge] = []
        
        // Trip count achievements
        let tripThresholds: [(Int, String, String)] = [
            (1, "car", "First Trip"),
            (10, "car.fill", "10 Trips"),
            (50, "car.2.fill", "50 Trips"),
            (100, "bus.fill", "Century Club"),
            (250, "airplane", "Frequent Traveler"),
            (500, "ferry.fill", "Road Warrior"),
            (1000, "train.side.front.car", "Travel Master")
        ]
        
        achievements += tripThresholds.map { threshold, symbol, title in
            AchievementBadge(title: title, systemImage: symbol, achieved: totalTrips >= threshold)
        }
        
        // Documentation achievements
        if tripsWithNotes >= 10 {
            achievements.append(AchievementBadge(title: "Storyteller", systemImage: "text.bubble", achieved: true))
        }
        if tripsWithPhotos >= 5 {
            achievements.append(AchievementBadge(title: "Photographer", systemImage: "camera", achieved: true))
        }
        if tripsWithAudio >= 3 {
            achievements.append(AchievementBadge(title: "Voice Logger", systemImage: "mic", achieved: true))
        }
        
        // Recovery achievement
        if recoveredTrips > 0 {
            achievements.append(AchievementBadge(title: "Survivor", systemImage: "heart.fill", achieved: true))
        }
        
        return achievements
    }
    
    // New computed property for time badges with thresholds in hours
    var timeAchievements: [AchievementBadge] {
        let thresholds: [(Double, String, String)] = [
            (5.0/60.0, "timer", "5 Minutes"),
            (30.0/60.0, "timer", "30 Minutes"),
            (1, "clock", "1 Hour"),
            (2, "clock.fill", "2 Hours"),
            (4, "hourglass", "4 Hours"),
            (12, "hourglass.tophalf.filled", "12 Hours"),
            (24, "hourglass.bottomhalf.filled", "24 Hours"),
            (30, "clock.arrow.2.circlepath", "30 Hours"),
            (48, "alarm", "48 Hours"),
            (100, "stopwatch", "100 Hours")
        ]
        
        // Unlock badges if tripManager.lifetimeDriveHours (in hours) >= threshold
        let lifetimeHours = tripManager.lifetimeDriveHours
        return thresholds.map { threshold, symbol, title in
            AchievementBadge(title: title, systemImage: symbol, achieved: lifetimeHours >= threshold)
        }
    }
    
    private func mileageProgress() -> (progress: Double, nextTitle: String) {
        let distanceValue = useKilometers ? lifetimeMiles * 1.60934 : lifetimeMiles
        for (i, threshold) in mileageThresholds.enumerated() {
            if distanceValue < threshold.0 {
                let prev = i > 0 ? mileageThresholds[i-1].0 : 0.0
                let progress = (distanceValue - prev) / (threshold.0 - prev)
                return (min(max(progress,0),1), threshold.2)
            }
        }
        return (1.0, "Maxed Out")
    }
    
    private func streakProgress() -> (progress: Double, nextTitle: String) {
        let thresholds: [(Int, String, String)] = [
            (3, "flame", "3 Day Streak"),
            (7, "flame.fill", "1 Week Streak"),
            (14, "calendar", "2 Week Streak"),
            (30, "calendar.badge.plus", "1 Month Streak"),
            (60, "trophy", "2 Month Streak"),
            (100, "crown", "100 Day Streak"),
            (365, "star.circle", "1 Year Streak")
        ]
        
        for (i, threshold) in thresholds.enumerated() {
            if longestStreak < threshold.0 {
                let prev = i > 0 ? thresholds[i-1].0 : 0
                let progress = Double(longestStreak - prev) / Double(threshold.0 - prev)
                return (min(max(progress, 0), 1), threshold.2)
            }
        }
        return (1.0, "Maxed Out")
    }
    
    private func specialProgress() -> (progress: Double, nextTitle: String) {
        let totalTrips = tripManager.trips.count
        let tripThresholds: [(Int, String, String)] = [
            (1, "car", "First Trip"),
            (10, "car.fill", "10 Trips"),
            (50, "car.2.fill", "50 Trips"),
            (100, "bus.fill", "Century Club"),
            (250, "airplane", "Frequent Traveler"),
            (500, "ferry.fill", "Road Warrior"),
            (1000, "train.side.front.car", "Travel Master")
        ]
        
        for (i, threshold) in tripThresholds.enumerated() {
            if totalTrips < threshold.0 {
                let prev = i > 0 ? tripThresholds[i-1].0 : 0
                let progress = Double(totalTrips - prev) / Double(threshold.0 - prev)
                return (min(max(progress, 0), 1), threshold.2)
            }
        }
        return (1.0, "Maxed Out")
    }
    
    private func timeProgress() -> (progress: Double, nextTitle: String) {
        let thresholds: [(Double, String, String)] = [
            (5.0/60.0, "timer", "5 Minutes"),
            (30.0/60.0, "timer", "30 Minutes"),
            (1, "clock", "1 Hour"),
            (2, "clock.fill", "2 Hours"),
            (4, "hourglass", "4 Hours"),
            (12, "hourglass.tophalf.filled", "12 Hours"),
            (24, "hourglass.bottomhalf.filled", "24 Hours"),
            (30, "clock.arrow.2.circlepath", "30 Hours"),
            (48, "alarm", "48 Hours"),
            (100, "stopwatch", "100 Hours")
        ]
        let lifetimeHours = tripManager.lifetimeDriveHours
        for (i, threshold) in thresholds.enumerated() {
            if lifetimeHours < threshold.0 {
                let prev = i > 0 ? thresholds[i-1].0 : 0.0
                let progress = (lifetimeHours - prev) / (threshold.0 - prev)
                return (min(max(progress,0),1), threshold.2)
            }
        }
        return (1.0, "Maxed Out")
    }
    
    var formattedTimeUntilMidnight: String {
        let totalSeconds = Int(timeUntilMidnight)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    var formattedLifetimeMiles: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: lifetimeMiles)) ?? String(format: "%.1f", lifetimeMiles)
    }
    
    var formattedLifetimeDistance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        let value = useKilometers ? lifetimeMiles * 1.60934 : lifetimeMiles
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    achievementSummarySection
                    Divider()
                    dailyStreakSection
                    Divider()
                    streakBadgesSection
                    Divider()
                    mileageBadgesSection
                    Divider()
                    timeBadgesSection
                    Divider()
                    specialBadgesSection
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
            .onAppear(perform: setupTimer)
            .onDisappear(perform: cleanupTimer)
        }
    }
    
    @State private var timer: Timer?
    
    // MARK: - View Components
    private var achievementSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievement Progress")
                .font(.headline)
            
            let totalAchievements = mileageAchievements.count + timeAchievements.count + streakAchievements.count + specialAchievements.count
            let unlockedAchievements = mileageAchievements.filter(\.achieved).count + timeAchievements.filter(\.achieved).count + streakAchievements.filter(\.achieved).count + specialAchievements.filter(\.achieved).count
            
            HStack(spacing: 16) {
                StatCard(label: "Unlocked", value: "\(unlockedAchievements)", accentColor: .green)
                StatCard(label: "Total", value: "\(totalAchievements)", accentColor: .blue)
                StatCard(label: "Progress", value: "\(Int(Double(unlockedAchievements)/Double(totalAchievements) * 100))%", accentColor: .purple)
            }
            
            ProgressView(value: Double(unlockedAchievements), total: Double(totalAchievements)) {
                Text("Overall Progress")
                    .font(.caption)
            }
        }
    }
    
    private var dailyStreakSection: some View {
        Group {
            Text("Daily Streak")
                .font(.headline)
            HStack(spacing: 16) {
                StatCard(label: "Current", value: "\(dailyStreak)", accentColor: .orange)
                StatCard(label: "Longest", value: "\(longestStreak)", accentColor: .red)
            }
            Text("Time until streak can be extended: \(formattedTimeUntilMidnight)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var streakBadgesSection: some View {
        DisclosureGroup(
            isExpanded: $showStreakBadges,
            content: {
                if showStreakBadges {
                    let (streakProg, streakNext) = streakProgress()
                    ProgressView(value: streakProg) {
                        Text("Progress to \(streakNext)")
                    }
                    .padding(.bottom, 8)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 16) {
                        ForEach(filteredAchievements(streakAchievements), id: \.title) { badge in
                            AchievementBadgeView(badge: badge, accentColor: .orange)
                        }
                    }
                }
            },
            label: {
                DisclosureGroupLabel(title: "Streak Badges", systemImage: "flame.fill", isExpanded: showStreakBadges)
            }
        )
    }
    
    private var mileageBadgesSection: some View {
        DisclosureGroup(
            isExpanded: $showMileageBadges,
            content: {
                if showMileageBadges {
                    let (mileProg, mileNext) = mileageProgress()
                    ProgressView(value: mileProg) {
                        Text("Progress to \(mileNext)")
                    }
                    .padding(.bottom, 8)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 16) {
                        ForEach(filteredAchievements(mileageAchievements), id: \.title) { badge in
                            AchievementBadgeView(badge: badge, accentColor: .blue)
                        }
                    }
                    StatCard(label: useKilometers ? "Lifetime Kilometers" : "Lifetime Miles", value: formattedLifetimeDistance, accentColor: .blue)
                }
            },
            label: {
                DisclosureGroupLabel(title: "Mileage Badges", systemImage: "car.fill", isExpanded: showMileageBadges)
            }
        )
    }
    
    private var timeBadgesSection: some View {
        DisclosureGroup(
            isExpanded: $showTimeBadges,
            content: {
                if showTimeBadges {
                    let (timeProg, timeNext) = timeProgress()
                    ProgressView(value: timeProg) {
                        Text("Progress to \(timeNext)")
                    }
                    .padding(.bottom, 8)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 16) {
                        ForEach(filteredAchievements(timeAchievements), id: \.title) { badge in
                            AchievementBadgeView(badge: badge, accentColor: .green)
                        }
                    }
                    StatCard(label: "Lifetime Hours", value: String(format: "%.1f", tripManager.lifetimeDriveHours), accentColor: .green)
                }
            },
            label: {
                DisclosureGroupLabel(title: "Time Badges", systemImage: "clock.fill", isExpanded: showTimeBadges)
            }
        )
    }
    
    private var specialBadgesSection: some View {
        DisclosureGroup(
            isExpanded: $showSpecialBadges,
            content: {
                if showSpecialBadges {
                    let (specialProg, specialNext) = specialProgress()
                    ProgressView(value: specialProg) {
                        Text("Progress to \(specialNext)")
                    }
                    .padding(.bottom, 8)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 16) {
                        ForEach(filteredAchievements(specialAchievements), id: \.title) { badge in
                            AchievementBadgeView(badge: badge, accentColor: .purple)
                        }
                    }
                    HStack(spacing: 16) {
                        StatCard(label: "Total Trips", value: "\(tripManager.trips.count)", accentColor: .purple)
                        StatCard(label: "Documented", value: "\(tripManager.trips.filter { !$0.notes.isEmpty }.count)", accentColor: .purple)
                    }
                }
            },
            label: {
                DisclosureGroupLabel(title: "Special Badges", systemImage: "star.fill", isExpanded: showSpecialBadges)
            }
        )
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
    
    private func updateTimeUntilMidnight() {
        let calendar = Calendar.current
        let now = Date()
        if let nextMidnight = calendar.nextDate(after: now, matching: DateComponents(hour:0, minute:0, second:0), matchingPolicy: .strict, direction: .forward) {
            timeUntilMidnight = nextMidnight.timeIntervalSince(now)
        } else {
            timeUntilMidnight = 0
        }
    }
    
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
    
    private func filteredAchievements<T: Collection>(_ achievements: T) -> [AchievementBadge] where T.Element == AchievementBadge {
        var filtered = Array(achievements)
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by unlocked status
        if showOnlyUnlocked {
            filtered = filtered.filter { $0.achieved }
        }
        
        return filtered
    }
}

struct StatCard: View {
    let label: String
    let value: String
    var accentColor: Color = .blue
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .monospacedDigit()
                .foregroundColor(accentColor)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(minWidth: 80, maxWidth: 140, minHeight: 60, maxHeight: 80)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}

struct AchievementBadgeView: View {
    let badge: AchievementBadge
    var accentColor: Color = .yellow
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: badge.systemImage)
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(badge.achieved ? accentColor : .gray)
                .padding(8)
            Text(badge.title)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundColor(badge.achieved ? .primary : .gray)
                .lineLimit(2)
        }
        .frame(minWidth: 100, maxWidth: 120, minHeight: 100, maxHeight: 120)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(badge.achieved ? accentColor.opacity(0.15) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(badge.achieved ? accentColor.opacity(0.4) : Color.clear, lineWidth: 2)
        )
        .scaleEffect(badge.achieved ? 1.0 : 0.95)
        .animation(.easeInOut(duration: 0.2), value: badge.achieved)
    }
}

struct DisclosureGroupLabel: View {
    let title: String
    let systemImage: String
    let isExpanded: Bool
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(.accentColor)
            Text(title)
                .font(.headline)
            Spacer()
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .foregroundColor(.secondary)
                .rotationEffect(.degrees(isExpanded ? 0 : -90))
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
    }
}

struct AchievementNotificationView: View {
    let achievement: AchievementBadge
    let onDismiss: () -> Void
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: achievement.systemImage)
                .font(.system(size: 50))
                .foregroundColor(.yellow)
                .scaleEffect(isVisible ? 1.2 : 1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.5), value: isVisible)
            
            VStack(spacing: 8) {
                Text("Achievement Unlocked!")
                    .font(.headline)
                    .fontWeight(.bold)
                Text(achievement.title)
                    .font(.title2)
                    .multilineTextAlignment(.center)
            }
            
            Button("Continue") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    onDismiss()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isVisible = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.4))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                onDismiss()
            }
        }
    }
}

#Preview {
    AchievementsView()
        .environmentObject(TripManager())
}
