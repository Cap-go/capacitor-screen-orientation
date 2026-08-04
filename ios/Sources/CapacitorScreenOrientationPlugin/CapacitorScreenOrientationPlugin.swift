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
    private let pluginVersion: String = "8.1.18"
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
    private var capViewController: CAPBridgeViewController?
    private var defaultSupportedOrientations: [Int] = []

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

        if let viewController = self.bridge?.viewController as? CAPBridgeViewController {
            self.capViewController = viewController
            self.defaultSupportedOrientations = viewController.supportedOrientations
        }
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

        guard let mask = getOrientationMask(from: orientationString) else {
            call.reject("Invalid orientation value: \(orientationString)")
            return
        }

        let bypassLock = call.getBool("bypassOrientationLock") ?? false

        DispatchQueue.main.async {
            if self.capViewController == nil,
               let viewController = self.bridge?.viewController as? CAPBridgeViewController {
                self.capViewController = viewController
                if self.defaultSupportedOrientations.isEmpty {
                    self.defaultSupportedOrientations = viewController.supportedOrientations
                }
            }

            self.capViewController?.supportedOrientations = self.orientationValues(from: mask)

            if #available(iOS 16.0, *) {
                guard let windowScene = self.currentWindowScene() else {
                    call.reject("No window scene available to lock orientation")
                    return
                }

                windowScene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                self.capViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
                    // Geometry update can fail when the requested orientation is already active
                    // or temporarily unavailable; the supportedOrientations mask still applies.
                    print("Screen orientation geometry update warning: \(error.localizedDescription)")
                }
            } else {
                let orientationValue = self.preferredInterfaceOrientationValue(from: orientationString)
                UIDevice.current.setValue(orientationValue, forKey: "orientation")
                UINavigationController.attemptRotationToDeviceOrientation()
            }

            if bypassLock {
                self.startMotionTracking()
            }

            call.resolve()
        }
    }

    @objc func unlock(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.stopMotionTracking()

            if self.capViewController == nil,
               let viewController = self.bridge?.viewController as? CAPBridgeViewController {
                self.capViewController = viewController
                if self.defaultSupportedOrientations.isEmpty {
                    self.defaultSupportedOrientations = viewController.supportedOrientations
                }
            }

            let restoredOrientations = self.defaultSupportedOrientations.isEmpty
                ? self.orientationValues(from: .all)
                : self.defaultSupportedOrientations
            self.capViewController?.supportedOrientations = restoredOrientations

            if #available(iOS 16.0, *) {
                guard let windowScene = self.currentWindowScene() else {
                    call.reject("No window scene available to unlock orientation")
                    return
                }

                windowScene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                self.capViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .all)) { error in
                    print("Screen orientation unlock geometry update warning: \(error.localizedDescription)")
                }
            } else {
                UINavigationController.attemptRotationToDeviceOrientation()
            }

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

    private func currentWindowScene() -> UIWindowScene? {
        if let scene = self.capViewController?.view.window?.windowScene {
            return scene
        }

        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
    }

    private func getCurrentOrientationType() -> String {
        let interfaceOrientation = currentWindowScene()?.interfaceOrientation ?? .portrait
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

    private func preferredInterfaceOrientationValue(from orientationString: String) -> Int {
        switch orientationString {
        case "any":
            return UIInterfaceOrientation.unknown.rawValue
        case "landscape", "landscape-primary":
            return UIInterfaceOrientation.landscapeLeft.rawValue
        case "landscape-secondary":
            return UIInterfaceOrientation.landscapeRight.rawValue
        case "portrait-secondary":
            return UIInterfaceOrientation.portraitUpsideDown.rawValue
        default:
            return UIInterfaceOrientation.portrait.rawValue
        }
    }

    private func orientationValues(from mask: UIInterfaceOrientationMask) -> [Int] {
        var values: [Int] = []

        if mask.contains(.portrait) {
            values.append(UIInterfaceOrientation.portrait.rawValue)
        }
        if mask.contains(.portraitUpsideDown) {
            values.append(UIInterfaceOrientation.portraitUpsideDown.rawValue)
        }
        if mask.contains(.landscapeLeft) {
            values.append(UIInterfaceOrientation.landscapeLeft.rawValue)
        }
        if mask.contains(.landscapeRight) {
            values.append(UIInterfaceOrientation.landscapeRight.rawValue)
        }

        return values
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
