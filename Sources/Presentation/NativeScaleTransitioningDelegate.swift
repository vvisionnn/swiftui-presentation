import SwiftUI

class NativeScaleTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
	// Return the animator object for presenting the view controller
	func animationController(
		forPresented presented: UIViewController,
		presenting: UIViewController,
		source: UIViewController
	) -> UIViewControllerAnimatedTransitioning? {
		NativeScaleTransition(reverse: false)
	}

	// Return the animator object for dismissing the view controller (optional)
	func animationController(
		forDismissed dismissed: UIViewController
	) -> UIViewControllerAnimatedTransitioning? {
		NativeScaleTransition(reverse: true)
	}
}
