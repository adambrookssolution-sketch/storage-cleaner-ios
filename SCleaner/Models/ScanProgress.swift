import Foundation

/// Represents the scan lifecycle states
enum ScanProgress: Equatable {
    case idle
    case scanning(processed: Int, total: Int)
    case hashing(processed: Int, total: Int)
    case completed(ScanResult)
    case failed(String)

    /// Progress fraction from 0.0 to 1.0
    var progressFraction: Double {
        switch self {
        case .scanning(let processed, let total):
            guard total > 0 else { return 0 }
            return Double(processed) / Double(total)
        case .hashing(let processed, let total):
            guard total > 0 else { return 0 }
            return Double(processed) / Double(total)
        case .completed:
            return 1.0
        default:
            return 0
        }
    }

    /// Whether a scan is currently in progress
    var isScanning: Bool {
        switch self {
        case .scanning, .hashing: return true
        default: return false
        }
    }

    /// Whether the hash computation phase is active
    var isHashing: Bool {
        if case .hashing = self { return true }
        return false
    }

    /// Whether the scan has completed
    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    static func == (lhs: ScanProgress, rhs: ScanProgress) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.scanning(let lp, let lt), .scanning(let rp, let rt)):
            return lp == rp && lt == rt
        case (.hashing(let lp, let lt), .hashing(let rp, let rt)):
            return lp == rp && lt == rt
        case (.completed(let lr), .completed(let rr)):
            return lr == rr
        case (.failed(let lm), .failed(let rm)):
            return lm == rm
        default:
            return false
        }
    }
}
