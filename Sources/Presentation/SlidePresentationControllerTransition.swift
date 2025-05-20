#if os(iOS)
import SwiftUI
import UIKit

/// An interactive transition built for the ``SlidePresentationController``.
///
/// ```
/// func animationController(
///     forPresented presented: UIViewController,
///     presenting: UIViewController,
///     source: UIViewController
/// ) -> UIViewControllerAnimatedTransitioning? {
///     let transition = SlidePresentationControllerTransition(...)
///     transition.wantsInteractiveStart = false
///     return transition
/// }
///
/// func animationController(
///     forDismissed dismissed: UIViewController
/// ) -> UIViewControllerAnimatedTransitioning? {
///     guard let presentationController = dismissed.presentationController as? SlidePresentationController else {
///         return nil
///     }
///     let transition = SlidePresentationControllerTransition(...)
///     transition.wantsInteractiveStart = presentationController.wantsInteractiveTransition
///     presentationController.transition(with: transition)
///     return transition
/// }
///
/// func interactionControllerForDismissal(
///     using animator: UIViewControllerAnimatedTransitioning
/// ) -> UIViewControllerInteractiveTransitioning? {
///     return animator as? SlidePresentationControllerTransition
/// }
/// ```
///
@available(iOS 14.0, *)
open class SlidePresentationControllerTransition: PresentationControllerTransition {
	public var edge: Edge
	public var prefersScaleEffect: Bool
	public var preferredFromCornerRadius: CGFloat?
	public var preferredToCornerRadius: CGFloat?

	public init(
		edge: Edge,
		prefersScaleEffect: Bool = true,
		preferredFromCornerRadius: CGFloat?,
		preferredToCornerRadius: CGFloat?,
		isPresenting: Bool,
		animation: Animation?
	) {
		self.edge = edge
		self.prefersScaleEffect = prefersScaleEffect
		self.preferredFromCornerRadius = preferredFromCornerRadius
		self.preferredToCornerRadius = preferredToCornerRadius
		super.init(isPresenting: isPresenting, animation: animation)
	}

	open override func configureTransitionAnimator(
		using transitionContext: any UIViewControllerContextTransitioning,
		animator: UIViewPropertyAnimator
	) {
		let isPresenting = isPresenting
		guard let presented = transitionContext.viewController(forKey: isPresenting ? .to : .from),
		      let presenting = transitionContext.viewController(forKey: isPresenting ? .from : .to)
		else {
			transitionContext.completeTransition(false)
			return
		}

		let frame = transitionContext.finalFrame(for: presented)
		#if targetEnvironment(macCatalyst)
		let isScaleEnabled = false
		let toCornerRadius = preferredToCornerRadius ?? 0
		let fromCornerRadius = preferredFromCornerRadius ?? 0
		#else
		let isScaleEnabled = prefersScaleEffect && presenting.view.convert(
			presenting.view.frame.origin,
			to: nil
		).y == 0 &&
			frame.origin.y == 0
		let toCornerRadius = preferredToCornerRadius ?? UIScreen.main.displayCornerRadius(min: 0)
		let fromCornerRadius = preferredFromCornerRadius ?? (preferredToCornerRadius ?? UIScreen.main.displayCornerRadius())
		#endif
		let safeAreaInsets = transitionContext.containerView.safeAreaInsets

		var dzTransform = CGAffineTransform(scaleX: 0.92, y: 0.92)
		switch edge {
		case .top:
			dzTransform = dzTransform.translatedBy(x: 0, y: safeAreaInsets.bottom / 2)
		case .bottom:
			dzTransform = dzTransform.translatedBy(x: 0, y: safeAreaInsets.top / 2)
		case .leading:
			switch presented.traitCollection.layoutDirection {
			case .rightToLeft:
				dzTransform = dzTransform.translatedBy(x: 0, y: safeAreaInsets.left / 2)
			default:
				dzTransform = dzTransform.translatedBy(x: 0, y: safeAreaInsets.right / 2)
			}
		case .trailing:
			switch presented.traitCollection.layoutDirection {
			case .leftToRight:
				dzTransform = dzTransform.translatedBy(x: 0, y: safeAreaInsets.right / 2)
			default:
				dzTransform = dzTransform.translatedBy(x: 0, y: safeAreaInsets.left / 2)
			}
		}

		presenting.view.layer.cornerCurve = .continuous
		presenting.view.layer.masksToBounds = true

		if isPresenting {
			transitionContext.containerView.addSubview(presented.view)
			presented.view.frame = frame
			presented.view.transform = presentationTransform(
				presented: presented,
				frame: frame
			)
			presented.view.layer.cornerRadius = fromCornerRadius
		} else {
			#if !targetEnvironment(macCatalyst)
			if isScaleEnabled {
				presenting.view.transform = dzTransform
				presenting.view.layer.cornerRadius = UIScreen.main.displayCornerRadius()
			}
			#endif
			presented.view.layer.cornerRadius = toCornerRadius
		}

		presented.view.layoutIfNeeded()

		let presentedTransform = isPresenting ? .identity : presentationTransform(
			presented: presented,
			frame: frame
		)
		let presentingTransform = isPresenting && isScaleEnabled ? dzTransform : .identity
		animator.addAnimations {
			presented.view.transform = presentedTransform
			presenting.view.transform = presentingTransform
			if isScaleEnabled {
				presenting.view.layer.cornerRadius = isPresenting ? UIScreen.main.displayCornerRadius() : 0
			}
		}
		animator.addCompletion { animatingPosition in
			if isScaleEnabled {
				presenting.view.layer.cornerRadius = 0
				presenting.view.layer.masksToBounds = true
				presenting.view.transform = .identity
			}
			presented.view.layer.cornerRadius = 0
			switch animatingPosition {
			case .end:
				transitionContext.completeTransition(true)
			default:
				transitionContext.completeTransition(false)
			}
		}
	}

	private func presentationTransform(
		presented: UIViewController,
		frame: CGRect
	) -> CGAffineTransform {
		switch edge {
		case .top:
			return CGAffineTransform(translationX: 0, y: -frame.maxY)
		case .bottom:
			return CGAffineTransform(translationX: 0, y: frame.maxY)
		case .leading:
			switch presented.traitCollection.layoutDirection {
			case .rightToLeft:
				return CGAffineTransform(translationX: frame.maxX, y: 0)
			default:
				return CGAffineTransform(translationX: -frame.maxX, y: 0)
			}
		case .trailing:
			switch presented.traitCollection.layoutDirection {
			case .leftToRight:
				return CGAffineTransform(translationX: frame.maxX, y: 0)
			default:
				return CGAffineTransform(translationX: -frame.maxX, y: 0)
			}
		}
	}
}

extension UIColor {
	var isTranslucent: Bool {
		var alpha: CGFloat = 0
		if getWhite(nil, alpha: &alpha) {
			return alpha < 1
		}
		return false
	}
}

#endif
