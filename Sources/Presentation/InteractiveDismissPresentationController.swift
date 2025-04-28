import SwiftUI
import UIKit

// MARK: - Helper Function (from UIGestureRecognizer+Extensions)

func frictionCurve(
	_ value: CGFloat,
	distance: CGFloat = 200,
	coefficient: CGFloat = 0.3
) -> CGFloat {
	if value < 0 {
		return -frictionCurve(abs(value), distance: distance, coefficient: coefficient)
	}
	// This formula provides a diminishing return effect for drags
	return (1.0 - (1.0 / ((value * coefficient / distance) + 1.0))) * distance
}

// MARK: - Presentation Controller

class InteractiveDismissPresentationController: UIPresentationController, UIGestureRecognizerDelegate {
	// --- Configuration ---
	var dismissalThreshold: CGFloat = 0.4 // 40% drag distance needed to dismiss
	var velocityThreshold: CGFloat = 500 // Point velocity needed to dismiss regardless of distance
	var allowedDismissDirection: Edge.Set = .bottom // Direction(s) user can drag to dismiss

	// Scale and corner radius settings
	var parentViewScaleFactor: CGFloat = 0.92 // Scale down to 92% of original size
	var parentViewCornerRadius: CGFloat = max(
		10,
		UIScreen.main.displayCornerRadius - 10
	) // Target corner radius for parent when presented

	// --- Private State ---
	private var interactiveTransition: UIPercentDrivenInteractiveTransition?
	private lazy var panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
	private weak var trackingScrollView: UIScrollView?
	private var translationOffset: CGPoint = .zero // Offset when interacting with scroll view
	private var currentTranslation: CGPoint = .zero // Raw translation from pan gesture
	private var lastInterpolatedRadius: CGFloat = 0 // Track last radius to prevent redundant animations

	// Store parent view's original properties to restore later
	private var originalParentCornerRadius: CGFloat = 0.0
	private var parentMaskLayer: CAShapeLayer?
	private var presentedViewMaskLayer: CAShapeLayer?
	// Use the extension for screen corner radius
	private let screenCornerRadius = UIScreen.main.displayCornerRadius

	let cancelAnimationDuration: TimeInterval = 0.25 // Slower snap-back duration
	let cancelAnimationDamping: CGFloat = 0.5 // Gentle spring damping
	let interactiveUpdateThreshold: CGFloat = 1.0 // Minimum change in radius to trigger update

	// --- UI Elements ---
	// Black background that will be visible around the scaled parent view
	private lazy var blackBackgroundView: UIView = {
		let view = UIView()
		view.backgroundColor = UIColor.black
		return view
	}()

	// --- Public Access for Delegate ---
	// The transitioning delegate needs to get the interactive transition object
	var dismissalInteractor: UIPercentDrivenInteractiveTransition? {
		interactiveTransition
	}

	// --- Overrides ---

	override var frameOfPresentedViewInContainerView: CGRect {
		guard let containerView = containerView else { return .zero }
		// Default: Full screen or adjust as needed (e.g., for a card/sheet)
		// For simplicity, let's assume a sheet-like presentation covering lower half
		let height = containerView.bounds.height
		return CGRect(
			x: 0,
			y: containerView.bounds.height - height,
			width: containerView.bounds.width,
			height: height
		)
		// --- OR ---
		// return containerView.bounds // For full screen
	}

	override func presentationTransitionWillBegin() {
		guard let containerView = containerView,
		      let coordinator = presentedViewController.transitionCoordinator else { return }

		// Add black background behind the parent view
		if let presentingView = presentingViewController.view,
		   let presentingSuperview = presentingView.superview {
			presentingSuperview.insertSubview(blackBackgroundView, belowSubview: presentingView)
			blackBackgroundView.frame = containerView.bounds
		}

		// --- Request Max Frame Rate ---
		let duration = coordinator.transitionDuration
		let frameRateRequest = FrameRateRequest(
			preferredFrameRate: Float(UIScreen.main.maximumFramesPerSecond),
			duration: duration
		)
		frameRateRequest.perform()
		// --- End Frame Rate Request ---

		// Parent View Setup
		if let presentingView = presentingViewController.view {
			if let layer = presentingView.layer.mask as? CAShapeLayer {
				originalParentCornerRadius = layer.path?.boundingBox.height ?? 0
			} else {
				originalParentCornerRadius = presentingView.layer.cornerRadius
			}

			let maskLayer = CAShapeLayer()
			parentMaskLayer = maskLayer
			presentingView.layer.mask = maskLayer
			// Start parent with screen corner radius
			updateParentViewMask(with: screenCornerRadius)
			lastInterpolatedRadius = screenCornerRadius
		}

		// Presented View Setup
		if let presentedView = presentedView {
			let presentedMaskLayer = CAShapeLayer()
			presentedViewMaskLayer = presentedMaskLayer
			presentedView.layer.mask = presentedMaskLayer
			// Presented view always has screen corner radius
			updatePresentedViewMask(with: screenCornerRadius)
		}

		coordinator.animate(alongsideTransition: { [weak self] _ in
			guard let self = self else { return }

			// Animate parent view scale and corner radius
			if let presentingView = presentingViewController.view {
				presentingView.transform = CGAffineTransform(
					scaleX: parentViewScaleFactor,
					y: parentViewScaleFactor
				)
				// Animate parent corner radius to the target smaller value
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

		// --- Request Max Frame Rate ---
		let duration = coordinator.transitionDuration
		let frameRateRequest = FrameRateRequest(
			preferredFrameRate: Float(UIScreen.main.maximumFramesPerSecond),
			duration: duration
		)
		frameRateRequest.perform()
		// --- End Frame Rate Request ---

		coordinator.animate(alongsideTransition: { [weak self] _ in
			guard let self = self else { return }

			// Animate parent view scale and corner radius back
			if let presentingView = presentingViewController.view {
				presentingView.transform = .identity
				// Animate parent corner radius back to screen corner radius
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
			// Restore original state only if transition wasn't cancelled
			if !context.isCancelled {
				if let presentingView = presentingViewController.view {
					if originalParentCornerRadius > 0 {
						presentingView.layer.cornerRadius = originalParentCornerRadius
					} else {
						presentingView.layer.mask = nil // Remove mask
					}
					parentMaskLayer = nil // Clean up mask layer
				}
				// Clean up presented view mask
				if let presentedView = presentedView {
					presentedView.layer.mask = nil
				}
				presentedViewMaskLayer = nil

				// Remove black background
				blackBackgroundView.removeFromSuperview()
			}
		})
	}

	// Helper to create a rounded CGPath
	private func createRoundedPath(bounds: CGRect, cornerRadius: CGFloat) -> CGPath {
		UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
	}

	// Helper to animate mask layer path
	private func animateMaskLayerPath(for layer: CAShapeLayer?, to finalPath: CGPath, duration: TimeInterval) {
		guard let layer = layer, let currentPath = layer.path else { return }

		let animation = CABasicAnimation(keyPath: "path")
		animation.fromValue = currentPath
		animation.toValue = finalPath
		animation.duration = duration
		animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

		// Prevent flicker
		layer.path = finalPath

		layer.add(animation, forKey: "pathAnimation")
	}

	// Update parent mask with animation during interactive transitions
	private func updateParentViewMask(with cornerRadius: CGFloat) {
		guard let presentingView = presentingViewController.view,
		      let maskLayer = parentMaskLayer else { return }

		let newPath = createRoundedPath(bounds: presentingView.bounds, cornerRadius: cornerRadius)

		// Check if we're in an interactive transition (dragging)
		if interactiveTransition != nil {
			// Only animate if the change is significant enough to be visible
			// This prevents too many small animations causing stutter
			if abs(lastInterpolatedRadius - cornerRadius) >= interactiveUpdateThreshold {
				// Use very short duration for interactive updates to feel responsive but smooth
				let shortDuration: TimeInterval = 0.08
				animateMaskLayerPath(for: maskLayer, to: newPath, duration: shortDuration)
				lastInterpolatedRadius = cornerRadius
			}
		} else {
			// For non-interactive changes, just set the path directly
			maskLayer.path = newPath
			lastInterpolatedRadius = cornerRadius
		}
	}

	// Update presented mask (now just sets the path directly)
	private func updatePresentedViewMask(with cornerRadius: CGFloat) {
		guard let presentedView = presentedView,
		      let maskLayer = presentedViewMaskLayer else { return }
		maskLayer.path = createRoundedPath(bounds: presentedView.bounds, cornerRadius: cornerRadius)
	}

	override func presentationTransitionDidEnd(_ completed: Bool) {
		if completed {
			// Add pan gesture only after presentation is complete
			panGesture.delegate = self
			presentedView?.addGestureRecognizer(panGesture)
		} else {
			blackBackgroundView.removeFromSuperview()
		}
	}

	override func dismissalTransitionDidEnd(_ completed: Bool) {
		if completed {
			blackBackgroundView.removeFromSuperview()
			// Ensure gesture recognizer is removed if dismissal completes
			if let presentedView = presentedView, presentedView.gestureRecognizers?.contains(panGesture) ?? false {
				presentedView.removeGestureRecognizer(panGesture)
			}
		}
	}

	override func containerViewDidLayoutSubviews() {
		super.containerViewDidLayoutSubviews()
		// Keep presented view frame updated if needed (e.g., rotation)
		// Only update if not currently panning interactively
		if interactiveTransition == nil {
			presentedView?.frame = frameOfPresentedViewInContainerView
		}
		blackBackgroundView.frame = containerView?.bounds ?? .zero

		// Update masks when layout changes
		// Parent corner radius depends on interaction state
		let currentProgress = interactiveTransition?.percentComplete ?? (presentedViewController.isBeingPresented ? 0 : 1)
		let parentRadius = interpolateCornerRadius(progress: currentProgress)
		updateParentViewMask(with: parentRadius)
		// Presented view always uses screen corner radius
		updatePresentedViewMask(with: screenCornerRadius)
	}

	// --- Gesture Handling ---

	@objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
		guard let presentedView = presentedView else { return }

		let translation = gesture.translation(in: presentedView.superview)
		let velocity = gesture.velocity(in: presentedView.superview)

		switch gesture.state {
		case .began:
			let shouldStartDismissal = canBeginDismissal(with: translation, velocity: velocity)
			if shouldStartDismissal, interactiveTransition == nil {
				interactiveTransition = UIPercentDrivenInteractiveTransition()
				// Start the dismissal process
				presentedViewController.dismiss(animated: true)
			}
			currentTranslation = translation.applying(CGAffineTransform(translationX: -translationOffset.x, y: -translationOffset.y))

		case .changed:
			currentTranslation = translation.applying(CGAffineTransform(translationX: -translationOffset.x, y: -translationOffset.y))

			guard let interactiveTransition = interactiveTransition else {
				// Handle rubber banding if not actively dismissing
				let adjustedTranslation = CGPoint(
					x: currentTranslation.x, // Handle X friction if needed
					y: frictionCurve(currentTranslation.y, distance: presentedView.bounds.height)
				)
				presentedView.transform = transformForTranslation(adjustedTranslation)
				return
			}

			// Update interactive transition progress
			let progress = calculateDismissalProgress(for: currentTranslation)
			interactiveTransition.update(progress)

			// --- Update Parent Corner Radius Progressively ---
			let interpolatedRadius = interpolateCornerRadius(progress: progress)
			updateParentViewMask(with: interpolatedRadius)
			// --- End Update Parent Corner Radius ---

			// Handle scroll view pinning if necessary
			if let scrollView = trackingScrollView {
				pinScrollViewIfNeeded(scrollView, translation: currentTranslation)
			}

		case .cancelled, .ended:
			guard let interactiveTransition = interactiveTransition else {
				// User interaction ended, but we weren't in an interactive dismissal
				animateToRestingPosition(velocity: velocity)
				resetInteractionState()
				return
			}

			let progress = calculateDismissalProgress(for: currentTranslation)
			let shouldFinish = shouldFinishDismissal(progress: progress, velocity: velocity)

			if shouldFinish, gesture.state == .ended {
				interactiveTransition.completionSpeed = 1.0
				interactiveTransition.finish()
				// Animate parent mask back to screen radius on finish
				animateParentMaskToRadius(screenCornerRadius, speed: 1.0)
				resetInteractionState()
			} else {
				// Cancel the dismissal
				interactiveTransition.completionSpeed = 0.8
				interactiveTransition.completionCurve = .easeInOut
				interactiveTransition.cancel()

				// Animate parent mask back to the presented radius on cancel
				animateParentMaskToRadius(parentViewCornerRadius, speed: 0.7)

				// Animate presented view back to identity
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
				// Also need to animate back explicitly if cancel was called implicitly
				animateToRestingPosition(velocity: .zero)
				// Reset state after animating back
				resetInteractionState() // Reset here needed for failure cases
			} else {
				// If it failed before interaction started, just reset
				resetInteractionState()
			}
		}
	}

	// Helper to interpolate corner radius based on progress
	private func interpolateCornerRadius(progress: CGFloat) -> CGFloat {
		// progress 0 = fully presented (parentViewCornerRadius)
		// progress 1 = fully dismissed (screenCornerRadius)
		let clampedProgress = max(0.0, min(1.0, progress))
		return parentViewCornerRadius + (screenCornerRadius - parentViewCornerRadius) * clampedProgress
	}

	// Helper to animate parent mask to a specific radius with speed matching transition
	private func animateParentMaskToRadius(_ targetRadius: CGFloat, speed: CGFloat) {
		guard let presentingView = presentingViewController.view, let maskLayer = parentMaskLayer else { return }
		let finalPath = createRoundedPath(bounds: presentingView.bounds, cornerRadius: targetRadius)

		// Calculate duration based on remaining progress and speed
		let remainingProgress = (targetRadius == screenCornerRadius) ?
			(1.0 - (interactiveTransition?.percentComplete ?? 0)) :
			(interactiveTransition?.percentComplete ?? 0)

		let baseDuration = (targetRadius == screenCornerRadius) ?
			(presentedViewController.transitionCoordinator?.transitionDuration ?? 0.3) :
			cancelAnimationDuration // Use cancel duration for animating back

		let duration = baseDuration * TimeInterval(remainingProgress / speed)

		animateMaskLayerPath(for: maskLayer, to: finalPath, duration: max(0.01, duration)) // Ensure duration > 0
		lastInterpolatedRadius = targetRadius
	}

	private func resetInteractionState() {
		interactiveTransition = nil // Crucial: Stops interaction driving
		trackingScrollView = nil
		translationOffset = .zero
		currentTranslation = .zero
	}

	// --- Dismissal Logic Helpers ---

	private func canBeginDismissal(with translation: CGPoint, velocity: CGPoint) -> Bool {
		// Allow starting only if dragging in the allowed direction
		if allowedDismissDirection.contains(.bottom), translation.y > 0 {
			return true
		}
		if allowedDismissDirection.contains(.top), translation.y < 0 {
			return true
		}
		// Add .leading, .trailing checks if needed
		return false
	}

	private func calculateDismissalProgress(for translation: CGPoint) -> CGFloat {
		guard containerView != nil else { return 0 }
		let presentedHeight = frameOfPresentedViewInContainerView.height // Use height even for horizontal pans for now
		let verticalProgress = allowedDismissDirection.contains(.bottom) ? translation.y / presentedHeight : 0
		// Add other directions if needed
		return max(0.0, min(1.0, verticalProgress)) // Clamp progress
	}

	private func shouldFinishDismissal(progress: CGFloat, velocity: CGPoint) -> Bool {
		let verticalVelocity = allowedDismissDirection.contains(.bottom) ? velocity.y : 0
		// Add other directions if needed

		if progress >= dismissalThreshold {
			// Finish if dragged past threshold, unless moving significantly back
			return verticalVelocity >= -50 // Small tolerance for slight upward movement
		} else {
			// Finish if velocity is high enough, regardless of distance
			return verticalVelocity >= velocityThreshold
		}
	}

	// --- Visual Feedback Helpers ---

	private func transformForTranslation(_ translation: CGPoint) -> CGAffineTransform {
		if allowedDismissDirection.contains(.bottom), translation.y >= 0 {
			// Only translate down during dismissal drag
			return CGAffineTransform(translationX: 0, y: translation.y)
		}
		// Apply friction for drags against the dismissal direction (rubber banding)
		if allowedDismissDirection.contains(.bottom), translation.y < 0 {
			let dy = frictionCurve(translation.y, distance: presentedView?.bounds.height ?? 300)
			return CGAffineTransform(translationX: 0, y: dy)
		}
		// Add other directions if needed
		return .identity
	}

	// Keep the updated animateToRestingPosition from before
	private func animateToRestingPosition(velocity: CGPoint) {
		guard let presentedView = presentedView, presentedView.transform != .identity else { return }
		UIView.animate(
			withDuration: cancelAnimationDuration, // e.g., 0.5
			delay: 0,
			usingSpringWithDamping: cancelAnimationDamping, // e.g., 0.8
			initialSpringVelocity: abs(velocity.y) / presentedView.bounds.height,
			options: [.allowUserInteraction, .beginFromCurrentState],
			animations: {
				presentedView.transform = .identity
			}
			// No completion needed here, as resetInteractionState was called before this
		)
	}

	// --- Scroll View Interaction ---

	private func isScrollViewAtTopEdge(_ scrollView: UIScrollView) -> Bool {
		if allowedDismissDirection.contains(.bottom) {
			return scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top
		}
		// Add checks for other edges if needed
		return true // Default to true if edge doesn't match scroll direction
	}

	private func pinScrollViewIfNeeded(_ scrollView: UIScrollView, translation: CGPoint) {
		if allowedDismissDirection.contains(.bottom), translation.y > 0 {
			// Pin scroll view to top when dragging down for dismissal
			let pinnedOffset = CGPoint(x: scrollView.contentOffset.x, y: -scrollView.adjustedContentInset.top)
			// Check before setting to avoid unnecessary updates and potential delegate loops
			if scrollView.contentOffset != pinnedOffset {
				scrollView.contentOffset = pinnedOffset
			}
		}
		// Add pinning logic for other edges if needed
	}

	// --- UIGestureRecognizerDelegate ---

	func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		// Only allow pan gesture to begin if no interactive transition is active
		interactiveTransition == nil
	}

	func gestureRecognizer(
		_ gestureRecognizer: UIGestureRecognizer,
		shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
	) -> Bool {
		// Allow simultaneous recognition ONLY with scroll views inside the presented content
		guard gestureRecognizer == panGesture,
		      let scrollView = otherGestureRecognizer.view as? UIScrollView,
		      let presentedView = presentedView,
		      scrollView.contentOffset.y <= 0
		else {
			return false
		}

		// Check if the scroll view is a subview of the presented view
		if scrollView.isDescendant(of: presentedView) {
			// If we are not tracking a scroll view yet, and this is a valid scroll view gesture
			if trackingScrollView == nil, otherGestureRecognizer is UIPanGestureRecognizer {
				trackingScrollView = scrollView
				// Record the initial offset when interaction starts
				translationOffset = scrollView.contentOffset
				if allowedDismissDirection.contains(.bottom) {
					translationOffset.y += scrollView.adjustedContentInset.top
				}
				// Add offset adjustments for other edges if needed
			}
			return true // Allow simultaneous recognition
		}
		return false
	}

	// Prioritize the pan gesture only when the scroll view is at the relevant edge
	func gestureRecognizer(
		_ gestureRecognizer: UIGestureRecognizer,
		shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
	) -> Bool {
		guard gestureRecognizer == panGesture,
		      let scrollView = trackingScrollView, // Only consider if we are tracking a scroll view
		      otherGestureRecognizer.view == scrollView
		else {
			return false
		}

		// If the scroll view is at the top edge (when dismissing downwards),
		// our pan gesture should take precedence (don't fail). Otherwise, let the scroll view pan.
		return !isScrollViewAtTopEdge(scrollView)
	}
}

// MARK: - Animator

class DismissAnimator: NSObject, UIViewControllerAnimatedTransitioning {
	// Increased duration for a slower dismissal
	let animationDuration: TimeInterval = 0.35 // Was 0.3

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
			y: containerView.bounds.height, // Animate downwards off-screen
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
			// Changed to easeOut for a smoother finish
			options: .curveEaseOut, // Was .curveEaseIn
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

// MARK: - Transitioning Delegate

class InteractiveDismissTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
	// Keep a reference to the presentation controller to access the interactor
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
		presentationController = controller // Store the reference
		return controller
	}

	func animationController(
		forDismissed dismissed: UIViewController
	) -> UIViewControllerAnimatedTransitioning? {
		DismissAnimator() // Provide the dismissal animator
	}

	func interactionControllerForDismissal(
		using animator: UIViewControllerAnimatedTransitioning
	) -> UIViewControllerInteractiveTransitioning? {
		// Return the interactor ONLY if the presentation controller has started one
		presentationController?.dismissalInteractor
	}
}
