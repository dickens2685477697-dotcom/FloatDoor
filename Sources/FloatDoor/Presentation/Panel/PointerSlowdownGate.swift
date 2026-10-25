import Foundation

/// Recognizes an intentional slow approach or stop, rather than a pass through
/// the trigger region. Coordinates and speed are in screen points.
struct PointerSlowdownGate {
    static let maximumSpeed: CGFloat = 120
    static let slowDuration: TimeInterval = 0.15
    private static let maximumSampleGap: TimeInterval = 0.1

    private var previousPoint: CGPoint?
    private var previousTimestamp: TimeInterval?
    private var previousRegion: CGRect?
    private var slowSince: TimeInterval?

    mutating func sample(at point: CGPoint, timestamp: TimeInterval, in region: CGRect) -> Bool {
        guard region.contains(point) else {
            reset()
            return false
        }

        defer {
            previousPoint = point
            previousTimestamp = timestamp
            previousRegion = region
        }

        guard let previousPoint, let previousTimestamp, previousRegion == region else {
            slowSince = nil
            return false
        }

        let elapsed = timestamp - previousTimestamp
        // A stalled run loop or a changed clock provides no evidence that the
        // pointer stayed slow during the missing samples.
        guard elapsed > 0, elapsed <= Self.maximumSampleGap else {
            slowSince = nil
            return false
        }

        let speed = hypot(point.x - previousPoint.x, point.y - previousPoint.y) / elapsed
        guard speed <= Self.maximumSpeed else {
            slowSince = nil
            return false
        }

        if slowSince == nil { slowSince = previousTimestamp }
        return timestamp - (slowSince ?? timestamp) >= Self.slowDuration
    }

    mutating func reset() {
        previousPoint = nil
        previousTimestamp = nil
        previousRegion = nil
        slowSince = nil
    }
}
