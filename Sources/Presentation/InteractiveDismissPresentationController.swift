import SwiftUI
import UIKit



class InteractiveDismissPresentationController: UIPresentationController, UIGestureRecognizerDelegate {
	var dismissalThreshold: CGFloat = 0.4
	var velocityThreshold: CGFloat = 500

	var parentViewScaleFactor: CGFloat = 0.92
	var parentViewCornerRadius: CGFloat = max(
		10,
		UIScreen.main.displayCornerRadius - 10
	)

	private var interactiveTransition: UIPercentDrivenInteractiveTransition?
	private lazy var panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
	private weak var trackingScrollView: UIScrollView?
	private var translationOffset: CGPoint = .zero
	private var currentTranslation: CGPoint = .zero
	private var lastInterpolatedRadius: CGFloat = 0

	private var originalParentCornerRadius: CGFloat = 0.0
	private var parentMaskLayer: CAShapeLayer?
	private var presentedViewMaskLayer: CAShapeLayer?
	private let screenCornerRadius = UIScreen.main.displayCornerRadius

	let cancelAnimationDuration: TimeInterval = 0.25
	let cancelAnimationDamping: CGFloat = 0.5
	let interactiveUpdateThreshold: CGFloat = 1.0

	private lazy var blackBackgroundView: UIView = {
		let view = UIView()
		view.backgroundColor = UIColor.black
		return view
	}()

	var dismissalInteractor: UIPercentDrivenInteractiveTransition? {
		interactiveTransition
	}

	override var frameOfPresentedViewInContainerView: CGRect {
		guard let containerView = containerView else { return .zero }
		let height = containerView.bounds.height
		return CGRect(
			x: 0,
			y: containerView.bounds.height - height,
			width: containerView.bounds.width,
			height: height
		)
	}

	override func presentationTransitionWillBegin() {
		guard let containerView = containerView,
		      let coordinator = presentedViewController.transitionCoordinator else { return }

		if let presentingView = presentingViewController.view,
		   let presentingSuperview = presentingView.superview {
			presentingSuperview.insertSubview(blackBackgroundView, belowSubview: presentingView)
			blackBackgroundView.frame = containerView.bounds
		}

		let duration = coordinator.transitionDuration
		let frameRateRequest = FrameRateRequest(
			preferredFrameRate: Float(UIScreen.main.maximumFramesPerSecond),
			duration: duration
		)
		frameRateRequest.perform()

		if let presentingView = presentingViewController.view {
			if let layer = presentingView.layer.mask as? CAShapeLayer {
				originalParentCornerRadius = layer.path?.boundingBox.height ?? 0
			} else {
				originalParentCornerRadius = presentingView.layer.cornerRadius
			}

			let maskLayer = CAShapeLayer()
			parentMaskLayer = maskLayer
			presentingView.layer.mask = maskLayer
			updateParentViewMask(with: screenCornerRadius)
			lastInterpolatedRadius = screenCornerRadius
		}

		if let presentedView = presentedView {
			let presentedMaskLayer = CAShapeLayer()
			presentedViewMaskLayer = presentedMaskLayer
			presentedView.layer.mask = presentedMaskLayer
			updatePresentedViewMask(with: screenCornerRadius)
		}

		coordinator.animate(alongsideTransition: { [weak self] _ in
			guard let self = self else { return }

			if let presentingView = presentingViewController.view {
				presentingView.transform = CGAffineTransform(
					scaleX: parentViewScaleFactor,
					y: parentViewScaleFactor
				)
				animateMaskLayerPath(
					for: parentMaskLayer,
					to: createRoundedPath(
						bounds: presentingView.bounds,
						cornerRadius: parentViewCornerRadius
					),
					duration: coordinator.transitionDuration
				)
				lastInterpolatedRadius = parentViewCornerRadius
			}
		})
	}

	override func dismissalTransitionWillBegin() {
		guard let coordinator = presentedViewController.transitionCoordinator else { return }

		let duration = coordinator.transitionDuration
		let frameRateRequest = FrameRateRequest(
			preferredFrameRate: Float(UIScreen.main.maximumFramesPerSecond),
			duration: duration
		)
		frameRateRequest.perform()

		coordinator.animate(alongsideTransition: { [weak self] _ in
			guard let self = self else { return }

			if let presentingView = presentingViewController.view {
				presentingView.transform = .identity
				animateMaskLayerPath(
					for: parentMaskLayer,
					to: createRoundedPath(
						bounds: presentingView.bounds,
						cornerRadius: screenCornerRadius
					),
					duration: coordinator.transitionDuration
				)
				lastInterpolatedRadius = screenCornerRadius
			}
		}, completion: { [weak self] context in
			guard let self = self else { return }
			if !context.isCancelled {
				if let presentingView = presentingViewController.view {
					if originalParentCornerRadius > 0 {
						presentingView.layer.cornerRadius = originalParentCornerRadius
					} else {
						presentingView.layer.mask = nil
					}
					parentMaskLayer = nil
				}
				if let presentedView = presentedView {
					presentedView.layer.mask = nil
				}
				presentedViewMaskLayer = nil
				blackBackgroundView.removeFromSuperview()
			}
		})
	}

	private func createRoundedPath(bounds: CGRect, cornerRadius: CGFloat) -> CGPath {
		UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
	}

	private func animateMaskLayerPath(for layer: CAShapeLayer?, to finalPath: CGPath, duration: TimeInterval) {
		guard let layer = layer, let currentPath = layer.path else { return }

		let animation = CABasicAnimation(keyPath: "path")
		animation.fromValue = currentPath
		animation.toValue = finalPath
		animation.duration = duration
		animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

		layer.path = finalPath
		layer.add(animation, forKey: "pathAnimation")
	}

	private func updateParentViewMask(with cornerRadius: CGFloat) {
		guard let presentingView = presentingViewController.view,
		      let maskLayer = parentMaskLayer else { return }

		let newPath = createRoundedPath(bounds: presentingView.bounds, cornerRadius: cornerRadius)

		if interactiveTransition != nil {
			if abs(lastInterpolatedRadius - cornerRadius) >= interactiveUpdateThreshold {
				let shortDuration: TimeInterval = 0.08
				animateMaskLayerPath(for: maskLayer, to: newPath, duration: shortDuration)
				lastInterpolatedRadius = cornerRadius
			}
		} else {
			maskLayer.path = newPath
			lastInterpolatedRadius = cornerRadius
		}
	}

	private func updatePresentedViewMask(with cornerRadius: CGFloat) {
		guard let presentedView = presentedView,
		      let maskLayer = presentedViewMaskLayer else { return }
		maskLayer.path = createRoundedPath(bounds: presentedView.bounds, cornerRadius: cornerRadius)
	}

	override func presentationTransitionDidEnd(_ completed: Bool) {
		if completed {
			panGesture.delegate = self
			presentedView?.addGestureRecognizer(panGesture)
		} else {
			blackBackgroundView.removeFromSuperview()
		}
	}

	override func dismissalTransitionDidEnd(_ completed: Bool) {
		if completed {
			blackBackgroundView.removeFromSuperview()
			if let presentedView = presentedView, presentedView.gestureRecognizers?.contains(panGesture) ?? false {
				presentedView.removeGestureRecognizer(panGesture)
			}
		}
	}

	override func containerViewDidLayoutSubviews() {
		super.containerViewDidLayoutSubviews()

		if interactiveTransition == nil {
			presentedView?.frame = frameOfPresentedViewInContainerView
		}
		blackBackgroundView.frame = containerView?.bounds ?? .zero

		let currentProgress = interactiveTransition?.percentComplete ?? (presentedViewController.isBeingPresented ? 0 : 1)
		let parentRadius = interpolateCornerRadius(progress: currentProgress)
		updateParentViewMask(with: parentRadius)
		updatePresentedViewMask(with: screenCornerRadius)
	}

	@objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
		guard let presentedView = presentedView else { return }

		let translation = gesture.translation(in: presentedView.superview)
		let velocity = gesture.velocity(in: presentedView.superview)

		switch gesture.state {
		case .began:
			let shouldStartDismissal = canBeginDismissal(with: translation, velocity: velocity)
			if shouldStartDismissal, interactiveTransition == nil {
				interactiveTransition = UIPercentDrivenInteractiveTransition()
				trackingScrollView?.isUserInteractionEnabled = false
				trackingScrollView?.isScrollEnabled = false
				presentedViewController.dismiss(animated: true)
			}
			currentTranslation = translation.applying(CGAffineTransform(translationX: -translationOffset.x, y: -translationOffset.y))

		case .changed:
			let currTranslation = translation.applying(CGAffineTransform(translationX: -translationOffset.x, y: -translationOffset.y))
			guard currTranslation.y >= 0 else { return }
			currentTranslation = currTranslation

			guard let interactiveTransition = interactiveTransition else {
				let adjustedTranslation = CGPoint(
					x: currentTranslation.x,
					y: frictionCurve(currentTranslation.y, distance: presentedView.bounds.height)
				)
				presentedView.transform = transformForTranslation(adjustedTranslation)
				return
			}

			let progress = calculateDismissalProgress(for: currentTranslation)
			interactiveTransition.update(progress)

			let interpolatedRadius = interpolateCornerRadius(progress: progress)
			updateParentViewMask(with: interpolatedRadius)

			if let scrollView = trackingScrollView {
				pinScrollViewIfNeeded(scrollView, translation: currentTranslation)
			}

		case .cancelled, .ended:
			trackingScrollView?.isUserInteractionEnabled = true
			trackingScrollView?.isScrollEnabled = true
			guard let interactiveTransition = interactiveTransition else {
				animateToRestingPosition(velocity: velocity)
				resetInteractionState()
				return
			}

			let progress = calculateDismissalProgress(for: currentTranslation)
			let shouldFinish = shouldFinishDismissal(progress: progress, velocity: velocity)

			if shouldFinish, gesture.state == .ended {
				interactiveTransition.completionSpeed = 1.0
				interactiveTransition.finish()
				animateParentMaskToRadius(screenCornerRadius, speed: 1.0)
				resetInteractionState()
			} else {
				interactiveTransition.completionSpeed = 0.8
				interactiveTransition.completionCurve = .easeInOut
				interactiveTransition.cancel()

				animateParentMaskToRadius(parentViewCornerRadius, speed: 0.7)

				UIView.animate(
					withDuration: cancelAnimationDuration,
					delay: 0,
					usingSpringWithDamping: cancelAnimationDamping,
					initialSpringVelocity: 0,
					options: [.allowUserInteraction, .beginFromCurrentState],
					animations: {
						presentedView.transform = .identity
					},
					completion: { [weak self] _ in
						self?.resetInteractionState()
					}
				)
			}

		default:
			if let interactiveTransition = interactiveTransition {
				interactiveTransition.cancel()
				animateToRestingPosition(velocity: .zero)
				resetInteractionState()
			} else {
				resetInteractionState()
			}
		}
	}

	private func interpolateCornerRadius(progress: CGFloat) -> CGFloat {
		let clampedProgress = max(0.0, min(1.0, progress))
		return parentViewCornerRadius + (screenCornerRadius - parentViewCornerRadius) * clampedProgress
	}

	private func animateParentMaskToRadius(_ targetRadius: CGFloat, speed: CGFloat) {
		guard let presentingView = presentingViewController.view, let maskLayer = parentMaskLayer else { return }
		let finalPath = createRoundedPath(bounds: presentingView.bounds, cornerRadius: targetRadius)

		let remainingProgress = (targetRadius == screenCornerRadius) ?
			(1.0 - (interactiveTransition?.percentComplete ?? 0)) :
			(interactiveTransition?.percentComplete ?? 0)

		let baseDuration = (targetRadius == screenCornerRadius) ?
			(presentedViewController.transitionCoordinator?.transitionDuration ?? 0.3) :
			cancelAnimationDuration

		let duration = baseDuration * TimeInterval(remainingProgress / speed)

		animateMaskLayerPath(for: maskLayer, to: finalPath, duration: max(0.01, duration))
		lastInterpolatedRadius = targetRadius
	}

	private func resetInteractionState() {
		interactiveTransition = nil
		trackingScrollView = nil
		translationOffset = .zero
		currentTranslation = .zero
	}

	private func canBeginDismissal(with translation: CGPoint, velocity: CGPoint) -> Bool {
		translation.y > 0
	}

	private func calculateDismissalProgress(for translation: CGPoint) -> CGFloat {
		guard containerView != nil else { return 0 }
		let presentedHeight = frameOfPresentedViewInContainerView.height
		let verticalProgress = translation.y / presentedHeight
		return max(0.0, min(1.0, verticalProgress))
	}

	private func shouldFinishDismissal(progress: CGFloat, velocity: CGPoint) -> Bool {
		let verticalVelocity = velocity.y

		if progress >= dismissalThreshold {
			return verticalVelocity >= -50
		} else {
			return verticalVelocity >= velocityThreshold
		}
	}

	private func transformForTranslation(_ translation: CGPoint) -> CGAffineTransform {
		if translation.y >= 0 {
			return CGAffineTransform(translationX: 0, y: translation.y)
		}
		if translation.y < 0 {
			let dy = frictionCurve(translation.y, distance: presentedView?.bounds.height ?? 300)
			return CGAffineTransform(translationX: 0, y: dy)
		}
		return .identity
	}

	private func animateToRestingPosition(velocity: CGPoint) {
		guard let presentedView = presentedView, presentedView.transform != .identity else { return }
		UIView.animate(
			withDuration: cancelAnimationDuration,
			delay: 0,
			usingSpringWithDamping: cancelAnimationDamping,
			initialSpringVelocity: abs(velocity.y) / presentedView.bounds.height,
			options: [.allowUserInteraction, .beginFromCurrentState],
			animations: {
				presentedView.transform = .identity
			}
		)
	}

	private func isScrollViewAtTopEdge(_ scrollView: UIScrollView) -> Bool {
		scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top
	}

	private func pinScrollViewIfNeeded(_ scrollView: UIScrollView, translation: CGPoint) {
		if translation.y > 0 {
			let pinnedOffset = CGPoint(x: scrollView.contentOffset.x, y: -scrollView.adjustedContentInset.top)
			if scrollView.contentOffset != pinnedOffset {
				scrollView.contentOffset = pinnedOffset
			}
		}
	}

	func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		interactiveTransition == nil
	}

	func gestureRecognizer(
		_ gestureRecognizer: UIGestureRecognizer,
		shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
	) -> Bool {
		guard gestureRecognizer == panGesture,
		      let scrollView = otherGestureRecognizer.view as? UIScrollView,
		      let presentedView = presentedView,
		      scrollView.contentOffset.y <= 0
		else {
			return false
		}

		if scrollView.isDescendant(of: presentedView) {
			if trackingScrollView == nil, otherGestureRecognizer is UIPanGestureRecognizer {
				trackingScrollView = scrollView
				translationOffset = scrollView.contentOffset
				translationOffset.y += scrollView.adjustedContentInset.top
			}
			return true
		}
		return false
	}

	func gestureRecognizer(
		_ gestureRecognizer: UIGestureRecognizer,
		shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
	) -> Bool {
		guard gestureRecognizer == panGesture,
		      let scrollView = trackingScrollView,
		      otherGestureRecognizer.view == scrollView
		else {
			return false
		}
		return !isScrollViewAtTopEdge(scrollView)
	}
}

class DismissAnimator: NSObject, UIViewControllerAnimatedTransitioning {
	let animationDuration: TimeInterval = 0.35

	func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
		animationDuration
	}

	func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
		guard let fromView = transitionContext.view(forKey: .from) else {
			transitionContext.completeTransition(false)
			return
		}

		let containerView = transitionContext.containerView
		let finalFrame = CGRect(
			x: 0,
			y: containerView.bounds.height,
			width: fromView.frame.width,
			height: fromView.frame.height
		)

		let duration = transitionDuration(using: transitionContext)

		FrameRateRequest(
			preferredFrameRate: Float(UIScreen.main.maximumFramesPerSecond),
			duration: duration
		)
		.perform()
		UIView.animate(
			withDuration: duration,
			delay: 0,
			options: .curveEaseOut,
			animations: {
				fromView.frame = finalFrame
			},
			completion: { finished in
				let success = !transitionContext.transitionWasCancelled
				if success {
					fromView.removeFromSuperview()
				}
				transitionContext.completeTransition(success)
			}
		)
	}
}

class InteractiveDismissTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
	private weak var presentationController: InteractiveDismissPresentationController?

	func presentationController(
		forPresented presented: UIViewController,
		presenting: UIViewController?,
		source: UIViewController
	) -> UIPresentationController? {
		let controller = InteractiveDismissPresentationController(
			presentedViewController: presented,
			presenting: presenting
		)
		presentationController = controller
		return controller
	}

	func animationController(
		forDismissed dismissed: UIViewController
	) -> UIViewControllerAnimatedTransitioning? {
		DismissAnimator()
	}

	func interactionControllerForDismissal(
		using animator: UIViewControllerAnimatedTransitioning
	) -> UIViewControllerInteractiveTransitioning? {
		presentationController?.dismissalInteractor
	}
}
