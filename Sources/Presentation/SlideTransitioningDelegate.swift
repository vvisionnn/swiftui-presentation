import SwiftUI

class SlideTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
	func interactionControllerForDismissal(
		using animator: any UIViewControllerAnimatedTransitioning
	) -> (any UIViewControllerInteractiveTransitioning)? {
		animator as? SlidePresentationControllerTransition
	}

	func presentationController(
		forPresented presented: UIViewController,
		presenting: UIViewController?,
		source: UIViewController
	) -> UIPresentationController? {
		let presentationController = SlidePresentationController(
			edge: .bottom,
			presentedViewController: presented,
			presenting: presenting
		)
		return presentationController
	}

	// Return the animator object for presenting the view controller
	func animationController(
		forPresented presented: UIViewController,
		presenting: UIViewController,
		source: UIViewController
	) -> UIViewControllerAnimatedTransitioning? {
		let transition = SlidePresentationControllerTransition(
			edge: .bottom,
			prefersScaleEffect: true,
			preferredFromCornerRadius: nil,
			preferredToCornerRadius: nil,
			isPresenting: true,
			animation: .smooth
		)
		transition.wantsInteractiveStart = false
		return transition
	}

	// Return the animator object for dismissing the view controller (optional)
	func animationController(
		forDismissed dismissed: UIViewController
	) -> UIViewControllerAnimatedTransitioning? {
		guard let presentationController = dismissed.presentationController as? InteractivePresentationController
		else { return nil }
		let animation: Animation? = presentationController.preferredDefaultAnimation()
		let transition = SlidePresentationControllerTransition(
			edge: .bottom,
			prefersScaleEffect: true,
			preferredFromCornerRadius: nil,
			preferredToCornerRadius: nil,
			isPresenting: false,
			animation: animation
		)
		transition.wantsInteractiveStart = presentationController.wantsInteractiveTransition
		presentationController.transition(with: transition)
		return transition
	}
}
