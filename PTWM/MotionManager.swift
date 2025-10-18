import Foundation
import CoreMotion
import Combine

enum MotionActivityType: String {
    case walking = "Walking"
    case running = "Running"
    case automotive = "Automotive"
    case cycling = "Cycling"
    case stationary = "Stationary"
    case unknown = "Unknown"
}

enum MotionManagerError: Error, LocalizedError {
    case activityNotAvailable
    case authorizationDenied
    
    var errorDescription: String? {
        switch self {
        case .activityNotAvailable:
            return "Motion activity tracking is not available on this device"
        case .authorizationDenied:
            return "Motion activity access has been denied"
        }
    }
}

class MotionManager: ObservableObject {
    // MARK: - Properties
    private let activityManager = CMMotionActivityManager()
    private let operationQueue = OperationQueue()
    
    @Published var currentActivity: CMMotionActivity?
    @Published var activityType: MotionActivityType = .unknown
    @Published var activityDescription: String = "Unknown"
    @Published var confidence: CMMotionActivityConfidence = .low
    @Published var isTracking: Bool = false
    @Published var error: MotionManagerError?
    
    // MARK: - Initialization
    init() {
        setupOperationQueue()
    }
    
    deinit {
        stopActivityUpdates()
    }
    
    // MARK: - Setup
    private func setupOperationQueue() {
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .utility
    }
    
    // MARK: - Public Methods
    func startActivityUpdates() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            DispatchQueue.main.async {
                self.error = .activityNotAvailable
            }
            return
        }
        
        activityManager.startActivityUpdates(to: operationQueue) { [weak self] activity in
            guard let self = self, let activity = activity else { return }
            
            DispatchQueue.main.async {
                self.currentActivity = activity
                self.activityType = self.determineActivityType(activity)
                self.activityDescription = self.activityType.rawValue
                self.confidence = activity.confidence
                self.isTracking = true
                self.error = nil
            }
        }
    }
    
    func stopActivityUpdates() {
        activityManager.stopActivityUpdates()
        DispatchQueue.main.async {
            self.isTracking = false
        }
    }
    
    func queryActivity(from start: Date, to end: Date, completion: @escaping ([CMMotionActivity]) -> Void) {
        guard CMMotionActivityManager.isActivityAvailable() else {
            completion([])
            return
        }
        
        activityManager.queryActivityStarting(from: start, to: end, to: operationQueue) { activities, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error querying activity: \(error.localizedDescription)")
                    completion([])
                } else {
                    completion(activities ?? [])
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private func determineActivityType(_ activity: CMMotionActivity) -> MotionActivityType {
        if activity.running { return .running }
        if activity.walking { return .walking }
        if activity.cycling { return .cycling }
        if activity.automotive { return .automotive }
        if activity.stationary { return .stationary }
        return .unknown
    }
    
    // MARK: - Static Methods
    static func describe(_ activity: CMMotionActivity) -> String {
        if activity.running { return "Running" }
        if activity.walking { return "Walking" }
        if activity.cycling { return "Cycling" }
        if activity.automotive { return "Automotive" }
        if activity.stationary { return "Stationary" }
        return "Unknown"
    }
    
    static func isAvailable() -> Bool {
        return CMMotionActivityManager.isActivityAvailable()
    }
}

// MARK: - SwiftUI Preview Helper
#if DEBUG
extension MotionManager {
    static var preview: MotionManager {
        let manager = MotionManager()
        manager.activityDescription = "Walking"
        manager.activityType = .walking
        manager.confidence = .high
        manager.isTracking = true
        return manager
    }
}
#endif
