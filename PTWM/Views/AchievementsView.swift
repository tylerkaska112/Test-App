import SwiftUI

struct AchievementBadge {
    let title: String
    let systemImage: String
    let achieved: Bool
    let description: String
    let currentValue: Double
    let targetValue: Double
    let unlockedDate: Date?
    let valueFormatter: (Double) -> String
}

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
    @State private var selectedAchievement: AchievementBadge?
    @State private var showAchievementDetail = false
    
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
        let distanceValue = useKilometers ? lifetimeMiles * 1.60934 : lifetimeMiles
        let unit = useKilometers ? "km" : "miles"
        
        return mileageThresholds.map { threshold, symbol, title in
            let unlocked = distanceValue >= threshold
            let unlockDate = unlocked ? getUnlockDate(for: "mileage_\(threshold)") : nil
            
            return AchievementBadge(
                title: title,
                systemImage: symbol,
                achieved: unlocked,
                description: "Travel a total lifetime distance of \(title.lowercased()).",
                currentValue: distanceValue,
                targetValue: threshold,
                unlockedDate: unlockDate,
                valueFormatter: { value in
                    String(format: "%.1f \(unit)", value)
                }
            )
        }
    }
    
    var streakAchievements: [AchievementBadge] {
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
            let unlocked = longestStreak >= threshold
            let unlockDate = unlocked ? getUnlockDate(for: "streak_\(threshold)") : nil
            
            return AchievementBadge(
                title: title,
                systemImage: symbol,
                achieved: unlocked,
                description: desc,
                currentValue: Double(longestStreak),
                targetValue: Double(threshold),
                unlockedDate: unlockDate,
                valueFormatter: { value in
                    "\(Int(value)) days"
                }
            )
        }
    }
    
    var specialAchievements: [AchievementBadge] {
        let totalTrips = tripManager.trips.count
        let recoveredTrips = tripManager.trips.filter { $0.isRecovered }.count
        let tripsWithNotes = tripManager.trips.filter { !$0.notes.isEmpty }.count
        let tripsWithPhotos = tripManager.trips.filter { !$0.photoURLs.isEmpty }.count
        let tripsWithAudio = tripManager.trips.filter { !$0.audioNotes.isEmpty }.count
        
        var achievements: [AchievementBadge] = []
        
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
            let unlocked = totalTrips >= threshold
            let unlockDate = unlocked ? getUnlockDate(for: "trips_\(threshold)") : nil
            
            return AchievementBadge(
                title: title,
                systemImage: symbol,
                achieved: unlocked,
                description: desc,
                currentValue: Double(totalTrips),
                targetValue: Double(threshold),
                unlockedDate: unlockDate,
                valueFormatter: { value in
                    "\(Int(value)) trips"
                }
            )
        }
        
        if tripsWithNotes >= 10 {
            achievements.append(AchievementBadge(
                title: "Storyteller",
                systemImage: "text.bubble",
                achieved: true,
                description: "Add notes to 10 different trips.",
                currentValue: Double(tripsWithNotes),
                targetValue: 10,
                unlockedDate: getUnlockDate(for: "storyteller"),
                valueFormatter: { value in "\(Int(value)) trips with notes" }
            ))
        } else {
            achievements.append(AchievementBadge(
                title: "Storyteller",
                systemImage: "text.bubble",
                achieved: false,
                description: "Add notes to 10 different trips.",
                currentValue: Double(tripsWithNotes),
                targetValue: 10,
                unlockedDate: nil,
                valueFormatter: { value in "\(Int(value)) trips with notes" }
            ))
        }
        
        if tripsWithPhotos >= 5 {
            achievements.append(AchievementBadge(
                title: "Photographer",
                systemImage: "camera",
                achieved: true,
                description: "Add photos to 5 different trips.",
                currentValue: Double(tripsWithPhotos),
                targetValue: 5,
                unlockedDate: getUnlockDate(for: "photographer"),
                valueFormatter: { value in "\(Int(value)) trips with photos" }
            ))
        } else {
            achievements.append(AchievementBadge(
                title: "Photographer",
                systemImage: "camera",
                achieved: false,
                description: "Add photos to 5 different trips.",
                currentValue: Double(tripsWithPhotos),
                targetValue: 5,
                unlockedDate: nil,
                valueFormatter: { value in "\(Int(value)) trips with photos" }
            ))
        }
        
        if tripsWithAudio >= 3 {
            achievements.append(AchievementBadge(
                title: "Voice Logger",
                systemImage: "mic",
                achieved: true,
                description: "Record audio notes for 3 different trips.",
                currentValue: Double(tripsWithAudio),
                targetValue: 3,
                unlockedDate: getUnlockDate(for: "voice_logger"),
                valueFormatter: { value in "\(Int(value)) trips with audio" }
            ))
        } else {
            achievements.append(AchievementBadge(
                title: "Voice Logger",
                systemImage: "mic",
                achieved: false,
                description: "Record audio notes for 3 different trips.",
                currentValue: Double(tripsWithAudio),
                targetValue: 3,
                unlockedDate: nil,
                valueFormatter: { value in "\(Int(value)) trips with audio" }
            ))
        }
        
        if recoveredTrips > 0 {
            achievements.append(AchievementBadge(
                title: "Survivor",
                systemImage: "heart.fill",
                achieved: true,
                description: "Successfully recover at least one trip from the trash.",
                currentValue: Double(recoveredTrips),
                targetValue: 1,
                unlockedDate: getUnlockDate(for: "survivor"),
                valueFormatter: { value in "\(Int(value)) trips recovered" }
            ))
        } else {
            achievements.append(AchievementBadge(
                title: "Survivor",
                systemImage: "heart.fill",
                achieved: false,
                description: "Successfully recover at least one trip from the trash.",
                currentValue: 0,
                targetValue: 1,
                unlockedDate: nil,
                valueFormatter: { _ in "0 trips recovered" }
            ))
        }
        
        return achievements
    }
    
    var timeAchievements: [AchievementBadge] {
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
        
        let lifetimeHours = tripManager.lifetimeDriveHours
        return thresholds.map { threshold, symbol, title, desc in
            let unlocked = lifetimeHours >= threshold
            let unlockDate = unlocked ? getUnlockDate(for: "time_\(threshold)") : nil
            
            return AchievementBadge(
                title: title,
                systemImage: symbol,
                achieved: unlocked,
                description: desc,
                currentValue: lifetimeHours,
                targetValue: threshold,
                unlockedDate: unlockDate,
                valueFormatter: { value in
                    String(format: "%.1f hours", value)
                }
            )
        }
    }
    
    private func getUnlockDate(for key: String) -> Date? {
        // This would ideally be stored in UserDefaults or Core Data
        // For now, return a placeholder date when unlocked
        return Date()
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
            .sheet(isPresented: $showAchievementDetail) {
                if let achievement = selectedAchievement {
                    AchievementDetailView(achievement: achievement)
                }
            }
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
                                .onTapGesture {
                                    selectedAchievement = badge
                                    showAchievementDetail = true
                                }
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
                                .onTapGesture {
                                    selectedAchievement = badge
                                    showAchievementDetail = true
                                }
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
                                .onTapGesture {
                                    selectedAchievement = badge
                                    showAchievementDetail = true
                                }
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
                                .onTapGesture {
                                    selectedAchievement = badge
                                    showAchievementDetail = true
                                }
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
        
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if showOnlyUnlocked {
            filtered = filtered.filter { $0.achieved }
        }
        
        return filtered
    }
}

// MARK: - Achievement Badge View
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
            }
            
            Text(badge.title)
                .font(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundColor(badge.achieved ? .primary : .secondary)
            
            if !badge.achieved {
                ProgressView(value: badge.currentValue, total: badge.targetValue)
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

// MARK: - Disclosure Group Label
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
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

// MARK: - Achievement Notification View
struct AchievementNotificationView: View {
    let achievement: AchievementBadge
    let onDismiss: () -> Void
    
    @State private var isShowing = false
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 16) {
                Image(systemName: achievement.systemImage)
                    .font(.system(size: 40))
                    .foregroundColor(.yellow)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Achievement Unlocked!")
                        .font(.caption)
                        .foregroundColor(.secondary)
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

// MARK: - Achievement Detail View
struct AchievementDetailView: View {
    let achievement: AchievementBadge
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Achievement Icon
                    Image(systemName: achievement.systemImage)
                        .font(.system(size: 80, weight: .medium))
                        .foregroundColor(achievement.achieved ? .yellow : .gray)
                        .padding(30)
                        .background(
                            Circle()
                                .fill(achievement.achieved ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.1))
                        )
                        .overlay(
                            Circle()
                                .stroke(achievement.achieved ? Color.yellow : Color.gray, lineWidth: 3)
                        )
                    
                    // Title
                    Text(achievement.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    // Status Badge
                    HStack {
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
                            
                            ProgressView(value: achievement.currentValue, total: achievement.targetValue)
                                .tint(.blue)
                            
                            let remaining = achievement.targetValue - achievement.currentValue
                            Text("\(achievement.valueFormatter(remaining)) remaining")
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

// MARK: - Stat Card
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
