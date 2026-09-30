import Foundation
import ObjectiveC
import UIKit

/// iPhone Duo fold, hinge, and bar placement.
/// The types landed in UIKit 9127.0.85 (iOS 27.1). This calls them through the
/// runtime so a build with the 27.0 SDK still works on the iPhone Duo simulator.
final class IPhoneDuoFold: NSObject {
    static let shared = IPhoneDuoFold()

    private let available: Bool
    private let divisionKind: AnyObject?
    private let occlusionKind: AnyObject?
    private var hingeStatus: Int?
    private var hingeRadians: Double?
    private var interaction: AnyObject?
    private var onChange: (() -> Void)?

    private override init() {
        let viewResponds = UIView.instancesRespond(to: NSSelectorFromString("reservedRegionsOfKind:options:"))
        let kindClass: AnyClass? = NSClassFromString("UIViewReservedRegionKind")
        let interactionClass: AnyClass? = NSClassFromString("UIHingeInteraction")
        available = viewResponds && kindClass != nil && interactionClass != nil
        if let kindClass = kindClass {
            divisionKind = IPhoneDuoFold.classObject(kindClass, "divisionRegionKind")
            occlusionKind = IPhoneDuoFold.classObject(kindClass, "occlusionRegionKind")
        } else {
            divisionKind = nil
            occlusionKind = nil
        }
        super.init()
    }

    func isFoldable(in view: UIView?) -> Bool {
        guard available else { return false }
        if let status = hingeStatus, status != 0 { return true }
        guard let view = view else { return false }
        return !regions(kind: divisionKind, in: view, options: 1).isEmpty
    }

    func foldState(in view: UIView?) -> [String: Any] {
        guard let view = view, isFoldable(in: view) else {
            return ["state": "flat", "isSeparating": false, "posture": "flat"]
        }
        let regions = allRegions(in: view)
        let angle = hingeDegrees
        let closed = angle.map { $0 < 20 } ?? (hingeStatus == 1)
        let divisions = closed ? [] : regions.filter { $0.kind == "division" }
        let division = divisions.first { $0.active } ?? divisions.first
        let folded: Bool
        if let angle = angle, division != nil {
            folded = (20...160).contains(angle)
        } else if hingeStatus == 2 {
            folded = division != nil
        } else if hingeStatus == 3 {
            folded = false
        } else {
            folded = division?.active == true
        }

        var result: [String: Any] = [
            "state": folded ? "half-opened" : "flat",
            "isSeparating": folded,
            "posture": "flat"
        ]
        if folded, let division = division {
            result["posture"] = division.frame.height >= division.frame.width ? "book" : "tabletop"
            result["hingeOrientation"] = division.frame.height >= division.frame.width ? "vertical" : "horizontal"
            result["hingeBounds"] = box(division.frame)
            result["hingeMargins"] = [
                "top": Int(division.margins.top.rounded()),
                "right": Int(division.margins.right.rounded()),
                "bottom": Int(division.margins.bottom.rounded()),
                "left": Int(division.margins.left.rounded())
            ]
        }
        let cameras = regions.filter { $0.kind == "occlusion" && $0.active }.map { box($0.frame) }
        if !cameras.isEmpty {
            result["cameraBounds"] = cameras
        }
        if hingeStatus != nil {
            let onInner = regions.contains { $0.kind == "division" }
            result["activeDisplay"] = (closed || !onInner) ? "outer" : "inner"
        }
        return result
    }

    func hingeAngle() -> [String: Any] {
        guard let degrees = hingeDegrees else {
            return ["angle": NSNull(), "status": NSNull()]
        }
        return [
            "angle": degrees,
            "status": statusName(hingeStatus) as Any? ?? NSNull()
        ]
    }

    func reservedRegions(in view: UIView?) -> [String: Any] {
        guard let view = view, available else { return ["regions": []] }
        let regions = allRegions(in: view).map { region -> [String: Any] in
            let frame = box(region.frame)
            var item: [String: Any] = [
                "x": frame["x"] ?? 0,
                "y": frame["y"] ?? 0,
                "width": frame["width"] ?? 0,
                "height": frame["height"] ?? 0,
                "kind": region.kind,
                "isActive": region.active
            ]
            item["margins"] = [
                "top": Int(region.margins.top.rounded()),
                "right": Int(region.margins.right.rounded()),
                "bottom": Int(region.margins.bottom.rounded()),
                "left": Int(region.margins.left.rounded())
            ]
            return item
        }
        return ["regions": regions]
    }

    func barPlacement(in view: UIView?) -> [String: Any] {
        guard let view = view else {
            return ["verticalBarEdge": NSNull(), "inset": 0]
        }
        view.layoutIfNeeded()
        let insets = view.safeAreaInsets
        let rightToLeft = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let edge: String?
        if insets.right >= 70 {
            edge = rightToLeft ? "leading" : "trailing"
        } else if insets.left >= 70 {
            edge = rightToLeft ? "trailing" : "leading"
        } else {
            edge = nil
        }
        let inset = edge == nil ? 0 : Int((edge == "trailing" && !rightToLeft || edge == "leading" && rightToLeft ? insets.right : insets.left).rounded())
        return ["verticalBarEdge": edge as Any? ?? NSNull(), "inset": inset]
    }

    func observe(in view: UIView, onChange: @escaping () -> Void) {
        guard available, interaction == nil, let interactionClass: AnyClass = NSClassFromString("UIHingeInteraction") else { return }
        self.onChange = onChange
        let block: @convention(block) (AnyObject, AnyObject) -> Void = { [weak self] _, update in
            self?.store(update)
            self?.onChange?()
        }
        let sel = NSSelectorFromString("initWithUpdateHandler:")
        typealias InitFn = @convention(c) (AnyObject, Selector, AnyObject) -> AnyObject?
        let allocated = interactionClass.alloc()
        guard let initFn = class_getMethodImplementation(interactionClass, sel) else { return }
        let interaction = unsafeBitCast(initFn, to: InitFn.self)(allocated, sel, block as AnyObject)
        self.interaction = interaction
        if let interaction = interaction {
            view.perform(NSSelectorFromString("addInteraction:"), with: interaction)
        }
    }

    private var hingeDegrees: Double? {
        guard let radians = hingeRadians, hingeStatus != 0 else { return nil }
        return radians * 180 / .pi
    }

    private func store(_ update: AnyObject) {
        guard let hinge = object(update, "hinge") else { return }
        hingeStatus = integer(hinge, "status")
        hingeRadians = double(hinge, "angle")
    }

    private func allRegions(in view: UIView) -> [Region] {
        regions(kind: divisionKind, in: view, options: 1) + regions(kind: occlusionKind, in: view, options: 1)
    }

    private func regions(kind: AnyObject?, in view: UIView, options: UInt) -> [Region] {
        guard let kind = kind else { return [] }
        let sel = NSSelectorFromString("reservedRegionsOfKind:options:")
        typealias Fn = @convention(c) (AnyObject, Selector, AnyObject, UInt) -> NSArray?
        let list = unsafeBitCast(view.method(for: sel), to: Fn.self)(view, sel, kind, options) ?? []
        return list.compactMap { item in
            guard let region = item as? AnyObject else { return nil }
            let kindObject = object(region, "kind")
            let name = kindObject?.description.contains("occlusion") == true ? "occlusion" : "division"
            return Region(
                kind: name,
                frame: rect(region, "frame"),
                margins: insets(region, "margins"),
                active: bool(region, "isActive")
            )
        }
    }

    private func statusName(_ status: Int?) -> String? {
        switch status {
        case 1: return "closed"
        case 2: return "partiallyOpen"
        case 3: return "fullyOpen"
        default: return nil
        }
    }

    private struct Region {
        var kind: String
        var frame: CGRect
        var margins: UIEdgeInsets
        var active: Bool
    }

    private func box(_ rect: CGRect) -> [String: Int] {
        return [
            "x": Int(rect.origin.x.rounded()),
            "y": Int(rect.origin.y.rounded()),
            "width": Int(rect.size.width.rounded()),
            "height": Int(rect.size.height.rounded())
        ]
    }

    private static func classObject(_ cls: AnyClass, _ name: String) -> AnyObject? {
        let sel = NSSelectorFromString(name)
        typealias Fn = @convention(c) (AnyClass, Selector) -> AnyObject?
        guard let imp = class_getMethodImplementation(object_getClass(cls), sel) else { return nil }
        return unsafeBitCast(imp, to: Fn.self)(cls, sel)
    }

    private func object(_ target: AnyObject, _ name: String) -> AnyObject? {
        let sel = NSSelectorFromString(name)
        typealias Fn = @convention(c) (AnyObject, Selector) -> AnyObject?
        return unsafeBitCast(target.method(for: sel), to: Fn.self)(target, sel)
    }

    private func integer(_ target: AnyObject, _ name: String) -> Int {
        let sel = NSSelectorFromString(name)
        typealias Fn = @convention(c) (AnyObject, Selector) -> Int
        return unsafeBitCast(target.method(for: sel), to: Fn.self)(target, sel)
    }

    private func double(_ target: AnyObject, _ name: String) -> Double {
        let sel = NSSelectorFromString(name)
        typealias Fn = @convention(c) (AnyObject, Selector) -> Double
        return unsafeBitCast(target.method(for: sel), to: Fn.self)(target, sel)
    }

    private func bool(_ target: AnyObject, _ name: String) -> Bool {
        let sel = NSSelectorFromString(name)
        typealias Fn = @convention(c) (AnyObject, Selector) -> Bool
        return unsafeBitCast(target.method(for: sel), to: Fn.self)(target, sel)
    }

    private func rect(_ target: AnyObject, _ name: String) -> CGRect {
        let sel = NSSelectorFromString(name)
        typealias Fn = @convention(c) (AnyObject, Selector) -> CGRect
        return unsafeBitCast(target.method(for: sel), to: Fn.self)(target, sel)
    }

    private func insets(_ target: AnyObject, _ name: String) -> UIEdgeInsets {
        let sel = NSSelectorFromString(name)
        typealias Fn = @convention(c) (AnyObject, Selector) -> UIEdgeInsets
        return unsafeBitCast(target.method(for: sel), to: Fn.self)(target, sel)
    }
}
