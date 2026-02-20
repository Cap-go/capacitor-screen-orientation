import Foundation
import Capacitor
import CoreMotion
import UIKit

/**
 * Capacitor Screen Orientation Plugin
 *
 * Provides screen orientation detection and control with support for
 * bypassing device orientation lock using Core Motion sensors.
 */
@objc(CapacitorScreenOrientationPlugin)
public class CapacitorScreenOrientationPlugin: CAPPlugin, CAPBridgedPlugin {
    private let pluginVersion: String = "8.1.12"
    public let identifier = "CapacitorScreenOrientationPlugin"
    public let jsName = "CapacitorScreenOrientation"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "orientation", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "lock", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "unlock", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "startOrientationTracking", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stopOrientationTracking", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "isOrientationLocked", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getPluginVersion", returnType: CAPPluginReturnPromise)
    ]

    private var motionManager: CMMotionManager?
    private var currentDeviceOrientation: UIDeviceOrientation = .portrait
    private var isTrackingWithMotion = false
    private var lastNotifiedOrientation: String?

    override public func load() {
        // Listen for device orientation changes from system
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )

        // Start monitoring device orientation
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }

    deinit {
        stopMotionTracking()
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func orientationDidChange() {
        // Skip system orientation changes when motion tracking is active
        // to avoid duplicate events
        guard !isTrackingWithMotion else { return }

        let orientation = UIDevice.current.orientation
        if orientation.isValidInterfaceOrientation {
            notifyOrientationChange(fromDeviceOrientation: orientation)
        }
    }

    @objc func orientation(_ call: CAPPluginCall) {
        let orientationType = getCurrentOrientationType()
        call.resolve(["type": orientationType])
    }

    @objc func lock(_ call: CAPPluginCall) {
        guard let orientationString = call.getString("orientation") else {
            call.reject("Orientation parameter is required")
            return
        }

        let bypassLock = call.getBool("bypassOrientationLock") ?? false

        DispatchQueue.main.async {
            // Lock the orientation at the app level
            if let mask = self.getOrientationMask(from: orientationString) {
                // Note: Actual implementation would need to communicate with AppDelegate
                // to set the supported interface orientations
                // For now, we'll just track the preference
                print("Locking orientation to: \(orientationString)")
            }

            // Start motion tracking if bypass is requested
            if bypassLock {
                self.startMotionTracking()
            }

            call.resolve()
        }
    }

    @objc func unlock(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            // Stop motion tracking
            self.stopMotionTracking()

            // Unlock orientation at app level
            print("Unlocking orientation")

            call.resolve()
        }
    }

    @objc func startOrientationTracking(_ call: CAPPluginCall) {
        let bypassLock = call.getBool("bypassOrientationLock") ?? false

        if bypassLock {
            startMotionTracking()
        }

        call.resolve()
    }

    @objc func stopOrientationTracking(_ call: CAPPluginCall) {
        stopMotionTracking()
        call.resolve()
    }

    @objc func isOrientationLocked(_ call: CAPPluginCall) {
        let uiOrientation = getCurrentOrientationType()

        if isTrackingWithMotion {
            // We have motion data, compare physical vs UI orientation
            let physicalOrientation = mapDeviceOrientationToString(currentDeviceOrientation)
            let locked = physicalOrientation != uiOrientation

            call.resolve([
                "locked": locked,
                "physicalOrientation": physicalOrientation,
                "uiOrientation": uiOrientation
            ])
        } else {
            // No motion tracking active, can't determine if locked
            // Return false by default, but note that we don't have physical orientation data
            call.resolve([
                "locked": false,
                "uiOrientation": uiOrientation
            ])
        }
    }

    @objc func getPluginVersion(_ call: CAPPluginCall) {
        call.resolve(["version": self.pluginVersion])
    }

    // MARK: - Core Motion Tracking

    private func startMotionTracking() {
        guard !isTrackingWithMotion else { return }

        motionManager = CMMotionManager()
        guard let motionManager = motionManager else { return }

        motionManager.accelerometerUpdateInterval = 0.2
        motionManager.gyroUpdateInterval = 0.2

        if motionManager.isAccelerometerAvailable {
            isTrackingWithMotion = true

            motionManager.startAccelerometerUpdates(to: .main) { [weak self] (data, _) in
                guard let self = self, let data = data else { return }

                let acceleration = data.acceleration
                let orientation = self.determineOrientation(from: acceleration)

                if orientation != self.currentDeviceOrientation {
                    self.currentDeviceOrientation = orientation
                    self.notifyOrientationChange(fromDeviceOrientation: orientation)
                }
            }

            print("Started motion-based orientation tracking")
        } else {
            print("Accelerometer not available")
        }
    }

    private func stopMotionTracking() {
        guard isTrackingWithMotion else { return }

        motionManager?.stopAccelerometerUpdates()
        motionManager = nil
        isTrackingWithMotion = false

        print("Stopped motion-based orientation tracking")
    }

    private func determineOrientation(from acceleration: CMAcceleration) -> UIDeviceOrientation {
        let threshold = 0.5

        if acceleration.x < -threshold {
            return .landscapeRight
        } else if acceleration.x > threshold {
            return .landscapeLeft
        } else if acceleration.y < -threshold {
            return .portrait
        } else if acceleration.y > threshold {
            return .portraitUpsideDown
        }

        return currentDeviceOrientation
    }

    // MARK: - Helper Methods

    private func getCurrentOrientationType() -> String {
        let interfaceOrientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
        return mapInterfaceOrientationToString(interfaceOrientation)
    }

    private func notifyOrientationChange(fromDeviceOrientation deviceOrientation: UIDeviceOrientation) {
        let orientationType = mapDeviceOrientationToString(deviceOrientation)

        // Only notify if orientation actually changed
        if orientationType != lastNotifiedOrientation {
            lastNotifiedOrientation = orientationType
            notifyListeners("screenOrientationChange", data: ["type": orientationType])
        }
    }

    private func mapInterfaceOrientationToString(_ orientation: UIInterfaceOrientation) -> String {
        switch orientation {
        case .portrait:
            return "portrait-primary"
        case .portraitUpsideDown:
            return "portrait-secondary"
        case .landscapeLeft:
            return "landscape-primary"
        case .landscapeRight:
            return "landscape-secondary"
        default:
            return "portrait-primary"
        }
    }

    private func mapDeviceOrientationToString(_ orientation: UIDeviceOrientation) -> String {
        switch orientation {
        case .portrait:
            return "portrait-primary"
        case .portraitUpsideDown:
            return "portrait-secondary"
        case .landscapeLeft:
            return "landscape-secondary" // Note: device left = interface right
        case .landscapeRight:
            return "landscape-primary" // Note: device right = interface left
        default:
            return "portrait-primary"
        }
    }

    private func getOrientationMask(from orientationString: String) -> UIInterfaceOrientationMask? {
        switch orientationString {
        case "any":
            return .all
        case "natural", "portrait":
            return .portrait
        case "landscape":
            return .landscape
        case "portrait-primary":
            return .portrait
        case "portrait-secondary":
            return .portraitUpsideDown
        case "landscape-primary":
            return .landscapeLeft
        case "landscape-secondary":
            return .landscapeRight
        default:
            return nil
        }
    }
}

// Helper extension
extension UIDeviceOrientation {
    var isValidInterfaceOrientation: Bool {
        switch self {
        case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            return true
        default:
            return false
        }
    }
}
