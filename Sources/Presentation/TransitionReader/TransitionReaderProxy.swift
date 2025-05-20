#if os(iOS)

import SwiftUI
import UIKit

@frozen
public struct TransitionReaderProxy {
	/// The progress state of the transition from 0 to 1 where 1 is fully presented.
	public var progress: CGFloat
	public var isTransitioning: Bool

	@usableFromInline
	init(progress: CGFloat, isTransitioning: Bool) {
		self.progress = progress
		self.isTransitioning = isTransitioning
	}
}

@MainActor private var transitionReaderAnimationKey: UInt = 0

extension UIViewController {
	@MainActor
	var transitionReaderAnimation: Animation? {
		get {
			if let box = objc_getAssociatedObject(self, &transitionReaderAnimationKey) as? ObjCBox<Animation?> {
				return box.value
			}
			return nil
		}
		set {
			let box = newValue.map { ObjCBox<Animation?>(value: $0) }
			objc_setAssociatedObject(self, &transitionReaderAnimationKey, box, .OBJC_ASSOCIATION_RETAIN)
		}
	}
}
#endif
