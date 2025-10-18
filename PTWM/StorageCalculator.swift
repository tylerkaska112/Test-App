import Foundation

// MARK: - Storage Calculator Helper

struct StorageCalculator {
    static func calculateTripStorageSize(trips: [Trip]) -> Int64 {
        var totalSize: Int64 = 0
        
        totalSize += Int64(trips.count * 500)
        
        for trip in trips {
            for audioURL in trip.audioNotes {
                if let fileSize = fileSize(at: audioURL) {
                    totalSize += fileSize
                }
            }
        }
        
        for trip in trips {
            for photoURL in trip.photoURLs {
                if let fileSize = fileSize(at: photoURL) {
                    totalSize += fileSize
                }
            }
        }
        
        for trip in trips {
            totalSize += Int64(trip.routeCoordinates.count * 24)
        }
        
        return totalSize
    }
    
    private static func fileSize(at url: URL) -> Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
    
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }
    
    static func storageBreakdown(trips: [Trip]) -> StorageBreakdown {
        var audioSize: Int64 = 0
        var photoSize: Int64 = 0
        var tripDataSize: Int64 = Int64(trips.count * 500)
        var routeDataSize: Int64 = 0
        
        for trip in trips {
            for audioURL in trip.audioNotes {
                if let size = fileSize(at: audioURL) {
                    audioSize += size
                }
            }
            
            for photoURL in trip.photoURLs {
                if let size = fileSize(at: photoURL) {
                    photoSize += size
                }
            }
            
            routeDataSize += Int64(trip.routeCoordinates.count * 24)
        }
        
        return StorageBreakdown(
            tripData: tripDataSize,
            audioFiles: audioSize,
            photoFiles: photoSize,
            routeData: routeDataSize
        )
    }
}

struct StorageBreakdown {
    let tripData: Int64
    let audioFiles: Int64
    let photoFiles: Int64
    let routeData: Int64
    
    var total: Int64 {
        tripData + audioFiles + photoFiles + routeData
    }
}
