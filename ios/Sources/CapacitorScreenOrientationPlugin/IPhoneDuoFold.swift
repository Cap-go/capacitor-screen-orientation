import Foundation
import UIKit

/// iPhone Duo fold, hinge, and bar placement (UIKit APIs in iOS 27.1).
#if canImport(UIKit, _version: 9127.0.85)
private let duoFoldSDKCompiled = true
#else
private let duoFoldSDKCompiled = false
#endif

final class IPhoneDuoFold: NSObject {
    static let shared = IPhoneDuoFold()

    private let available: Bool
    private var hingeStatus: Int?
    private var hingeRadians: Double?
    private var onChange: (() -> Void)?

#if canImport(UIKit, _version: 9127.0.85)
    private var interaction: UIHingeInteraction?
#endif

    private override init() {
        if duoFoldSDKCompiled {
            if #available(iOS 27.1, *) {
                available = true
            } else {
                available = false
            }
        } else {
            available = false
        }
        super.init()
    }

    func isFoldable(in view: UIView?) -> Bool {
        guard available else { return false }
        if let status = hingeStatus, status != 0 { return true }
        guard let view = view else { return false }
#if canImport(UIKit, _version: 9127.0.85)
        if #available(iOS 27.1, *) {
            return !regions(kind: .division, in: view).isEmpty
        }
#endif
        return false
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
        guard available else { return }
#if canImport(UIKit, _version: 9127.0.85)
        guard interaction == nil else { return }
        guard #available(iOS 27.1, *) else { return }
        self.onChange = onChange
        let interaction = UIHingeInteraction { [weak self] _, update in
            guard let self else { return }
            if let hinge = update.hinge {
                self.hingeStatus = self.statusCode(hinge.status)
                self.hingeRadians = hinge.angle
            }
            self.onChange?()
        }
        self.interaction = interaction
        view.addInteraction(interaction)
#endif
    }

    private var hingeDegrees: Double? {
        guard let radians = hingeRadians, hingeStatus != 0 else { return nil }
        return radians * 180 / .pi
    }

    private func allRegions(in view: UIView) -> [Region] {
#if canImport(UIKit, _version: 9127.0.85)
        if #available(iOS 27.1, *) {
            return regions(kind: .division, in: view) + regions(kind: .occlusion, in: view)
        }
#endif
        return []
    }

#if canImport(UIKit, _version: 9127.0.85)
    @available(iOS 27.1, *)
    private func regions(kind: UIView.ReservedRegion.Kind, in view: UIView) -> [Region] {
        let queryOptions: UIView.ReservedRegion.QueryOptions = .includeInactive
        return view.reservedRegions(kind: kind, options: queryOptions).map { region in
            Region(
                kind: regionKindName(region.kind),
                frame: region.frame,
                margins: region.margins,
                active: region.isActive
            )
        }
    }

    @available(iOS 27.1, *)
    private func regionKindName(_ kind: UIView.ReservedRegion.Kind) -> String {
        switch kind {
        case .occlusion:
            return "occlusion"
        case .division:
            return "division"
        default:
            return "division"
        }
    }

    @available(iOS 27.1, *)
    private func statusCode(_ status: UIHinge.Status) -> Int {
        switch status {
        case .closed:
            return 1
        case .partiallyOpen:
            return 2
        case .fullyOpen:
            return 3
        case .unknown:
            return 0
        @unknown default:
            return 0
        }
    }
#endif

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
}
