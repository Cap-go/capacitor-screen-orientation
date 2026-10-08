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
    private let pluginVersion: String = "8.4.0"
    public let identifier = "CapacitorScreenOrientationPlugin"
    public let jsName = "CapacitorScreenOrientation"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "orientation", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "lock", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "unlock", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "startOrientationTracking", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stopOrientationTracking", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "isOrientationLocked", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "isDeviceFoldable", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getFoldState", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getHingeAngle", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getReservedRegions", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getBarPlacement", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setVerticalBarBehavior", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getSizeClass", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getPluginVersion", returnType: CAPPluginReturnPromise)
    ]

    private var motionManager: CMMotionManager?
    private var currentDeviceOrientation: UIDeviceOrientation = .portrait
    private var isTrackingWithMotion = false
    private var lastNotifiedOrientation: String?
    private var capViewController: CAPBridgeViewController?
    private var defaultSupportedOrientations: [Int] = []
    private var lastSizeClassKey: String?
    private var sizeClassProbe: SizeClassProbe?

    private final class SizeClassProbe: UIView {
        var onLayout: (() -> Void)?

        override func layoutSubviews() {
            super.layoutSubviews()
            onLayout?()
        }
    }

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
        DispatchQueue.main.async {
            self.attachSizeClassProbe()
            self.notifySizeClassIfChanged()
            if let view = self.bridge?.webView {
                IPhoneDuoFold.shared.observe(in: view) { [weak self] in
                    self?.notifyListeners("hingeAngleChange", data: IPhoneDuoFold.shared.hingeAngle())
                    self?.notifyListeners("foldStateChange", data: IPhoneDuoFold.shared.foldState(in: view))
                }
            }
        }
    }

    deinit {
        stopMotionTracking()
        sizeClassProbe?.removeFromSuperview()
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func orientationDidChange() {
        notifySizeClassIfChanged()

        // Skip system orientation changes when motion tracking is active
        // to avoid duplicate events
        guard !isTrackingWithMotion else { return }

        let orientation = UIDevice.current.orientation
        if orientation.isValidInterfaceOrientation {
            notifyOrientationChange(fromDeviceOrientation: orientation)
        }
    }

    @objc func isDeviceFoldable(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let foldable = IPhoneDuoFold.shared.isFoldable(in: self.bridge?.webView)
            call.resolve(["foldable": foldable, "supportsTabletop": foldable])
        }
    }

    @objc func getFoldState(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            call.resolve(IPhoneDuoFold.shared.foldState(in: self.bridge?.webView))
        }
    }

    @objc func getHingeAngle(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            call.resolve(IPhoneDuoFold.shared.hingeAngle())
        }
    }

    @objc func getReservedRegions(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            call.resolve(IPhoneDuoFold.shared.reservedRegions(in: self.bridge?.webView))
        }
    }

    @objc func getBarPlacement(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            call.resolve(IPhoneDuoFold.shared.barPlacement(in: self.bridge?.webView))
        }
    }

    @objc func setVerticalBarBehavior(_ call: CAPPluginCall) {
        call.resolve(["applied": false])
    }

    @objc func getSizeClass(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            call.resolve(self.currentSizeClass())
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
                // iOS 15 has no public API to force a rotation (requestGeometryUpdate is iOS 16+).
                // supportedOrientations was set above, so the UI rotates into the locked mask as soon as
                // the device orientation allows it; the lock is not guaranteed to rotate the UI immediately.
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

    private func currentSizeClass() -> [String: Any] {
        let view = self.bridge?.webView
        let width = Double(view?.bounds.width ?? UIScreen.main.bounds.width)
        let height = Double(view?.bounds.height ?? UIScreen.main.bounds.height)
        let traits = view?.traitCollection
        let horizontal = sizeName(traits?.horizontalSizeClass, points: width, regularAt: 600)
        let vertical = sizeName(traits?.verticalSizeClass, points: height, regularAt: 480)
        return [
            "horizontal": horizontal,
            "vertical": vertical,
            "widthClass": materialWidth(width),
            "heightClass": height >= 900 ? "expanded" : height >= 480 ? "medium" : "compact"
        ]
    }

    private func attachSizeClassProbe() {
        guard sizeClassProbe == nil, let webView = bridge?.webView else { return }
        let probe = SizeClassProbe(frame: webView.bounds)
        probe.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        probe.isUserInteractionEnabled = false
        probe.backgroundColor = .clear
        probe.onLayout = { [weak self] in
            self?.notifySizeClassIfChanged()
        }
        webView.addSubview(probe)
        sizeClassProbe = probe
    }

    private func notifySizeClassIfChanged() {
        let sizeClass = currentSizeClass()
        let key = "\(sizeClass["horizontal"] ?? "")-\(sizeClass["vertical"] ?? "")-\(sizeClass["widthClass"] ?? "")-\(sizeClass["heightClass"] ?? "")"
        guard key != lastSizeClassKey else { return }
        lastSizeClassKey = key
        notifyListeners("sizeClassChange", data: sizeClass)
    }

    private func sizeName(_ sizeClass: UIUserInterfaceSizeClass?, points: Double, regularAt: Double) -> String {
        switch sizeClass {
        case .some(.regular):
            return "regular"
        case .some(.compact):
            return "compact"
        default:
            return points >= regularAt ? "regular" : "compact"
        }
    }

    private func materialWidth(_ width: Double) -> String {
        if width >= 1600 { return "extraLarge" }
        if width >= 1200 { return "large" }
        if width >= 840 { return "expanded" }
        if width >= 600 { return "medium" }
        return "compact"
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
