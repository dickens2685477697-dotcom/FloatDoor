import AppKit
import Darwin
import Foundation

/// Owns an advisory file lock for the lifetime of the process.
///
/// A file lock is used instead of relying only on Launch Services because
/// macOS can run two copies of the same app when they are launched from
/// different locations (for example, Xcode and a mounted release DMG).
final class SingleInstanceLock {
    private let fileDescriptor: Int32

    init?(fileURL: URL) {
        let descriptor = open(
            fileURL.path,
            O_CREAT | O_RDWR,
            mode_t(S_IRUSR | S_IWUSR)
        )
        guard descriptor >= 0 else { return nil }

        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return nil
        }

        fileDescriptor = descriptor
    }

    deinit {
        flock(fileDescriptor, LOCK_UN)
        close(fileDescriptor)
    }
}

enum SingleInstanceCoordinator {
    static let bundleIdentifier = "com.floatdoor.app"
    static let openPortalNotification = Notification.Name(
        "com.floatdoor.app.open-portal"
    )

    static func acquireLock() -> SingleInstanceLock? {
        SingleInstanceLock(fileURL: lockFileURL)
    }

    static var hasExistingInstance: Bool {
        existingApplication != nil
    }

    static func requestExistingInstanceToOpen() {
        DistributedNotificationCenter.default().post(
            name: openPortalNotification,
            object: bundleIdentifier,
            userInfo: nil
        )

        existingApplication?.activate(options: [])
    }

    private static var existingApplication: NSRunningApplication? {
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications.first { application in
            guard application.processIdentifier != currentProcessIdentifier else { return false }

            // The executable-name fallback also catches an Xcode/SwiftPM run,
            // which does not necessarily have the packaged app's bundle ID.
            return application.bundleIdentifier == bundleIdentifier
                || application.executableURL?.lastPathComponent == "FloatDoor"
        }
    }

    private static var lockFileURL: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(bundleIdentifier).instance.lock", isDirectory: false)
    }
}
