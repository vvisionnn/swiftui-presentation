import SwiftUI

// A presentation controller that presents the view in a full screen sheet
@available(iOS 14.0, *)
open class SlidePresentationController: InteractivePresentationController {
	public var edge: Edge

	public override var edges: Edge.Set {
		get { Edge.Set(edge) }
		set {}
	}

	open override var wantsInteractiveDismissal: Bool {
		prefersInteractiveDismissal
	}

	open override var presentationStyle: UIModalPresentationStyle {
		.overFullScreen
	}

	public init(
		edge: Edge = .bottom,
		presentedViewController: UIViewController,
		presenting presentingViewController: UIViewController?
	) {
		self.edge = edge
		super.init(
			presentedViewController: presentedViewController,
			presenting: presentingViewController
		)
		dimmingView.isHidden = false
	}

	open override func presentedViewTransform(for translation: CGPoint) -> CGAffineTransform {
		if prefersInteractiveDismissal {
			return super.presentedViewTransform(for: translation)
		}
		return .identity
	}

	open override func transformPresentedView(transform: CGAffineTransform) {
		super.transformPresentedView(transform: transform)

		if transform.isIdentity {
			presentedViewController.view.layer.cornerRadius = 0
		} else {
			presentedViewController.view.layer.cornerRadius = UIScreen.main.displayCornerRadius()
		}
	}

	open override func presentationTransitionWillBegin() {
		super.presentationTransitionWillBegin()
		presentedViewController.view.layer.cornerCurve = .continuous
	}

	open override func presentationTransitionDidEnd(_ completed: Bool) {
		super.presentationTransitionDidEnd(completed)
		if completed {
			presentedViewController.view.layer.cornerRadius = 0
		}
	}

	open override func containerViewDidLayoutSubviews() {
		super.containerViewDidLayoutSubviews()

		presentingViewController.view.isHidden = presentedViewController.presentedViewController != nil
	}
}
