import SwiftUI

@inline(__always)
public func withCATransaction(
	_ completion: @escaping () -> Void
) {
	CATransaction.begin()
	CATransaction.setCompletionBlock(completion)
	CATransaction.commit()
}
