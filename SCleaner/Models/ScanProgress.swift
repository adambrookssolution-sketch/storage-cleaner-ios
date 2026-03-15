import Foundation

/// Represents the scan lifecycle states
enum ScanProgress: Equatable {
    case idle
    case scanning(processed: Int, total: Int)
    /// Partial result emitted during scan so dashboard cards update in real-time
    case partialResult(processed: Int, total: Int, result: ScanResult)
    case hashing(processed: Int, total: Int)
    case completed(ScanResult)
    case failed(String)

    /// Progress fraction from 0.0 to 1.0 (combined: scanning 0-40%, hashing 40-90%)
    var progressFraction: Double {
        switch self {
        case .scanning(let processed, let total):
            guard total > 0 else { return 0 }
            return Double(processed) / Double(total) * 0.4
        case .partialResult(let processed, let total, _):
            guard total > 0 else { return 0.4 }
            return Double(processed) / Double(total) * 0.4
        case .hashing(let processed, let total):
            guard total > 0 else { return 0.4 }
            return 0.4 + Double(processed) / Double(total) * 0.5
        case .completed:
            return 1.0
        default:
            return 0
        }
    }

    /// Whether a scan is currently in progress
    var isScanning: Bool {
        switch self {
        case .scanning, .partialResult, .hashing: return true
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
        case (.partialResult(let lp, let lt, _), .partialResult(let rp, let rt, _)):
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
