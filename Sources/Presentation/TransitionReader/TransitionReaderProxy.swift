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
#endif
