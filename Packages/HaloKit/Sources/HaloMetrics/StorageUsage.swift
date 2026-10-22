#if os(macOS)
import Foundation

/// Space on the startup volume, counting purgeable space as free, as Finder does.
struct StorageUsage: Equatable {
    var freeBytes: Int64
    var totalBytes: Int64

    static func read() -> StorageUsage? {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
        guard let values = try? URL(filePath: "/").resourceValues(forKeys: keys),
              let free = values.volumeAvailableCapacityForImportantUsage,
              let total = values.volumeTotalCapacity
        else { return nil }
        return StorageUsage(freeBytes: free, totalBytes: Int64(total))
    }
}
#endif
