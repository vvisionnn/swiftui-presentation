#if os(iOS)
import SwiftUI
import UIKit

@frozen
public struct TransitionReader<Content: View>: View {
	public typealias Proxy = TransitionReaderProxy
	var content: (TransitionReaderProxy) -> Content
	@Binding var progress: CGFloat
	@Binding var isTransitioning: Bool

	public init(
		progress: Binding<CGFloat>,
		isTransitioning: Binding<Bool>,
		@ViewBuilder content: @escaping (TransitionReaderProxy) -> Content
	) {
		self._progress = progress
		self._isTransitioning = isTransitioning
		self.content = content
	}

	public var body: some View {
		content(.init(progress: progress, isTransitioning: isTransitioning))
			.background(
				TransitionReaderAdapter(
					progress: $progress,
					isTransitioning: $isTransitioning
				)
			)
	}
}
#endif
