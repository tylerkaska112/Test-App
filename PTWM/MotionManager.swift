import Foundation
import CoreMotion
import Combine

class MotionManager: ObservableObject {
    private let activityManager = CMMotionActivityManager()
    @Published var currentActivity: CMMotionActivity?
    @Published var activityDescription: String = "Unknown"

    init() {
        startActivityUpdates()
    }
    
    func startActivityUpdates() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity = activity else { return }
            DispatchQueue.main.async {
                self?.currentActivity = activity
                self?.activityDescription = MotionManager.describe(activity)
            }
        }
    }
    
    func stopActivityUpdates() {
        activityManager.stopActivityUpdates()
    }
    
    static func describe(_ activity: CMMotionActivity) -> String {
        if activity.walking { return "Walking" }
        if activity.running { return "Running" }
        if activity.automotive { return "Automotive" }
        if activity.cycling { return "Cycling" }
        if activity.stationary { return "Stationary" }
        return "Unknown"
    }
}
