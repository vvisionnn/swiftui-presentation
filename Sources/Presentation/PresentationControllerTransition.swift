#if os(iOS)

import SwiftUI
import UIKit

@available(iOS 14.0, *)
open class PresentationControllerTransition: UIPercentDrivenInteractiveTransition, UIViewControllerAnimatedTransitioning {
	public let isPresenting: Bool
	public let animation: Animation?
	private var animator: UIViewPropertyAnimator?

	private var transitionDuration: CGFloat = 0
	open override var duration: CGFloat {
		transitionDuration
	}

	public init(
		isPresenting: Bool,
		animation: Animation?
	) {
		self.isPresenting = isPresenting
		self.animation = animation
		super.init()
	}

	// MARK: - UIViewControllerAnimatedTransitioning

	open override func startInteractiveTransition(
		_ transitionContext: UIViewControllerContextTransitioning
	) {
		super.startInteractiveTransition(transitionContext)
		if let presenting = transitionContext.viewController(forKey: isPresenting ? .to : .from) {
			presenting.transitionReaderAnimation = animation
		}
		transitionDuration = transitionDuration(using: transitionContext)
	}

	open func transitionDuration(
		using transitionContext: UIViewControllerContextTransitioning?
	) -> TimeInterval {
		guard transitionContext?.isAnimated == true else { return 0 }
		return animation?.duration(defaultDuration: 0.35) ?? 0.35
	}

	public func animateTransition(
		using transitionContext: UIViewControllerContextTransitioning
	) {
		transitionDuration = transitionDuration(using: transitionContext)
		let animator = makeTransitionAnimatorIfNeeded(using: transitionContext)
		let delay = animation?.delay ?? 0
		if let presentationController = transitionContext
			.presentationController(isPresenting: isPresenting) as? PresentationController {
			presentationController.layoutBackgroundViews()
		}
		animator.startAnimation(afterDelay: delay)
		DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
			FrameRateRequest
				.maxFrameRate(duration: animator.duration)
				.perform()
		}

		if !transitionContext.isAnimated {
			animator.stopAnimation(false)
			animator.finishAnimation(at: .end)
		}
	}

	open func animationEnded(_ transitionCompleted: Bool) {
		animator = nil
	}

	public func interruptibleAnimator(
		using transitionContext: UIViewControllerContextTransitioning
	) -> UIViewImplicitlyAnimating {
		let animator = makeTransitionAnimatorIfNeeded(using: transitionContext)
		return animator
	}

	open override func responds(to aSelector: Selector!) -> Bool {
		let responds = super.responds(to: aSelector)
		if aSelector == #selector(interruptibleAnimator(using:)) {
			return responds && wantsInteractiveStart
		}
		return responds
	}

	private func makeTransitionAnimatorIfNeeded(
		using transitionContext: UIViewControllerContextTransitioning
	) -> UIViewPropertyAnimator {
		if let animator = animator {
			return animator
		}
		let animator = UIViewPropertyAnimator(
			animation: animation,
			defaultDuration: duration,
			defaultCompletionCurve: completionCurve
		)
		configureTransitionAnimator(using: transitionContext, animator: animator)
		self.animator = animator
		return animator
	}

	open func configureTransitionAnimator(
		using transitionContext: UIViewControllerContextTransitioning,
		animator: UIViewPropertyAnimator
	) {
		guard let presented = transitionContext.viewController(forKey: isPresenting ? .to : .from),
		      let presenting = transitionContext.viewController(forKey: isPresenting ? .from : .to)
		else {
			transitionContext.completeTransition(false)
			return
		}

		if isPresenting {
			let presentedFrame = transitionContext.finalFrame(for: presented)
			transitionContext.containerView.addSubview(presented.view)
			presented.view.frame = presentedFrame
			presented.view.layoutIfNeeded()

			let transform = CGAffineTransform(
				translationX: 0,
				y: presentedFrame.size.height + transitionContext.containerView.safeAreaInsets.bottom
			)
			presented.view.transform = transform
			animator.addAnimations {
				presented.view.transform = .identity
			}
		} else {
			if presenting.view.superview == nil {
				transitionContext.containerView.insertSubview(presenting.view, at: 0)
				presenting.view.frame = transitionContext.finalFrame(for: presenting)
				presenting.view.layoutIfNeeded()
			}
			let frame = transitionContext.finalFrame(for: presented)
			let dy = transitionContext.containerView.frame.height - frame.origin.y
			let transform = CGAffineTransform(
				translationX: 0,
				y: dy
			)
			presented.view.layoutIfNeeded()

			animator.addAnimations {
				presented.view.transform = transform
			}
		}
		animator.addCompletion { animatingPosition in
			switch animatingPosition {
			case .end:
				transitionContext.completeTransition(true)
			default:
				transitionContext.completeTransition(false)
			}
		}
	}
}

extension UIViewControllerContextTransitioning {
	func presentationController(isPresenting: Bool) -> UIPresentationController? {
		viewController(forKey: isPresenting ? .to : .from)?._activePresentationController
	}
}

extension Animation {
	public func duration(defaultDuration: CGFloat) -> TimeInterval {
		guard let resolved = Resolved(animation: self) else { return defaultDuration }
		switch resolved.timingCurve {
		case .default:
			return defaultDuration / resolved.speed
		default:
			return (resolved.timingCurve.duration ?? defaultDuration) / resolved.speed
		}
	}

	public var delay: TimeInterval? {
		guard let resolved = Resolved(animation: self) else { return nil }
		return resolved.delay
	}

	public var speed: Double? {
		guard let resolved = Resolved(animation: self) else { return nil }
		return resolved.speed
	}

	public func resolved() -> Resolved? {
		Resolved(animation: self)
	}

	public struct Resolved: Codable, Equatable {
		public enum TimingCurve: Codable, Equatable {
			case `default`

			public struct CustomAnimation: Codable, Equatable {
				public var duration: TimeInterval?
			}

			case custom(CustomAnimation)

			public struct BezierAnimation: Codable, Equatable {
				public struct AnimationCurve: Codable, Equatable {
					public var ax: Double
					public var bx: Double
					public var cx: Double
					public var ay: Double
					public var by: Double
					public var cy: Double
				}

				public var duration: TimeInterval
				public var curve: AnimationCurve
			}

			case bezier(BezierAnimation)

			public struct SpringAnimation: Codable, Equatable {
				public var mass: Double
				public var stiffness: Double
				public var damping: Double
				public var initialVelocity: Double
			}

			case spring(SpringAnimation)

			public struct FluidSpringAnimation: Codable, Equatable {
				public var duration: Double
				public var dampingFraction: Double
				public var blendDuration: TimeInterval
			}

			case fluidSpring(FluidSpringAnimation)

			init?(animator: Any) {
				func project<T>(_ animator: T) -> TimingCurve? {
					switch _typeName(T.self, qualified: false) {
					case "DefaultAnimation":
						return .default
					case "BezierAnimation":
						guard MemoryLayout<BezierAnimation>.size == MemoryLayout<T>.size else {
							return nil
						}
						let bezier = unsafeBitCast(animator, to: BezierAnimation.self)
						return .bezier(bezier)
					case "SpringAnimation":
						guard MemoryLayout<SpringAnimation>.size == MemoryLayout<T>.size else {
							return nil
						}
						let spring = unsafeBitCast(animator, to: SpringAnimation.self)
						return .spring(spring)
					case "FluidSpringAnimation":
						guard MemoryLayout<FluidSpringAnimation>.size == MemoryLayout<T>.size else {
							return nil
						}
						let fluidSpring = unsafeBitCast(animator, to: FluidSpringAnimation.self)
						return .fluidSpring(fluidSpring)
					default:
						if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
							guard animator is (any SwiftUI.CustomAnimation) else { return nil }
							let duration = Mirror(reflecting: animator).descendant("duration") as? TimeInterval
							return .custom(CustomAnimation(duration: duration))
						}
						return nil
					}
				}
				guard let timingCurve = _openExistential(animator, do: project) else {
					return nil
				}
				self = timingCurve
			}

			public var duration: TimeInterval? {
				switch self {
				case .default:
					return nil
				case let .custom(custom):
					return custom.duration
				case let .bezier(bezierCurve):
					return bezierCurve.duration
				case let .spring(springCurve):
					let naturalFrequency = sqrt(springCurve.stiffness / springCurve.mass)
					let dampingRatio = springCurve.damping / (2.0 * naturalFrequency)
					guard dampingRatio < 1 else {
						let duration = 2 * .pi / (naturalFrequency * dampingRatio)
						return duration
					}
					let decayRate = dampingRatio * naturalFrequency
					let duration = -log(0.01) / decayRate
					return duration
				case let .fluidSpring(fluidSpringCurve):
					return fluidSpringCurve.duration + fluidSpringCurve.blendDuration
				}
			}
		}

		public var timingCurve: TimingCurve
		public var delay: TimeInterval
		public var speed: Double

		public init(
			timingCurve: TimingCurve,
			delay: TimeInterval,
			speed: Double
		) {
			self.timingCurve = timingCurve
			self.delay = delay
			self.speed = speed
		}

		public init?(animation: Animation) {
			var animator: Any
			if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
				animator = animation.base
			} else {
				guard let base = Mirror(reflecting: animation).descendant("base") else {
					return nil
				}
				animator = base
			}
			var delay: TimeInterval = 0
			var speed: TimeInterval = 1
			var mirror = Mirror(reflecting: animator)
			while let base = mirror.descendant("_base") ?? mirror.descendant("base") ?? mirror.descendant("animation") {
				if let modifier = mirror.descendant("modifier") {
					mirror = Mirror(reflecting: modifier)
				}
				if let d = mirror.descendant("delay") as? TimeInterval {
					delay += d
				}
				if let s = mirror.descendant("speed") as? TimeInterval {
					speed *= s
				}
				animator = base
				mirror = Mirror(reflecting: animator)
			}
			guard let timingCurve = TimingCurve(animator: animator) else {
				return nil
			}
			self.timingCurve = timingCurve
			self.delay = delay
			self.speed = speed
		}
	}
}

final class AnimationTimingCurveProvider: NSObject, UITimingCurveProvider {
	let timingCurve: Animation.Resolved.TimingCurve
	init(timingCurve: Animation.Resolved.TimingCurve) {
		self.timingCurve = timingCurve
	}

	required init?(coder: NSCoder) {
		if let data = coder.decodeData(),
		   let timingCurve = try? JSONDecoder().decode(Animation.Resolved.TimingCurve.self, from: data) {
			self.timingCurve = timingCurve
		} else {
			return nil
		}
	}

	func encode(with coder: NSCoder) {
		if let data = try? JSONEncoder().encode(timingCurve) {
			coder.encode(data)
		}
	}

	func copy(with zone: NSZone? = nil) -> Any {
		AnimationTimingCurveProvider(timingCurve: timingCurve)
	}

	// MARK: - UITimingCurveProvider

	var timingCurveType: UITimingCurveType {
		switch timingCurve {
		case .custom, .default:
			return .builtin
		case .bezier:
			return .cubic
		case .fluidSpring, .spring:
			return .spring
		}
	}

	var cubicTimingParameters: UICubicTimingParameters? {
		switch timingCurve {
		case let .bezier(bezierCurve):
			let curve = bezierCurve.curve
			let p1x = curve.cx / 3
			let p1y = curve.cy / 3
			let p1 = CGPoint(x: p1x, y: p1y)
			let p2x = curve.cx - (1 / 3) * (curve.cx - curve.bx)
			let p2y = curve.cy - (1 / 3) * (curve.cy - curve.by)
			let p2 = CGPoint(x: p2x, y: p2y)
			return UICubicTimingParameters(
				controlPoint1: p1,
				controlPoint2: p2
			)
		case .custom, .default, .fluidSpring, .spring:
			return nil
		}
	}

	var springTimingParameters: UISpringTimingParameters? {
		switch timingCurve {
		case let .spring(springCurve):
			return UISpringTimingParameters(
				mass: springCurve.mass,
				stiffness: springCurve.stiffness,
				damping: springCurve.damping,
				initialVelocity: CGVector(
					dx: springCurve.initialVelocity,
					dy: springCurve.initialVelocity
				)
			)
		case let .fluidSpring(fluidSpringCurve):
			let initialVelocity = log(fluidSpringCurve.dampingFraction) / (fluidSpringCurve.duration - fluidSpringCurve.blendDuration)
			return UISpringTimingParameters(
				dampingRatio: fluidSpringCurve.dampingFraction,
				initialVelocity: CGVector(
					dx: initialVelocity,
					dy: initialVelocity
				)
			)
		case .bezier, .custom, .default:
			return nil
		}
	}
}

extension UIViewPropertyAnimator {
	public convenience init(
		animation: Animation?,
		defaultDuration: TimeInterval = 0.35,
		defaultCompletionCurve: UIView.AnimationCurve = .easeInOut
	) {
		if let resolved = animation?.resolved() {
			switch resolved.timingCurve {
			case .default:
				self.init(
					duration: defaultDuration / resolved.speed,
					curve: defaultCompletionCurve.toSwiftUI()
				)
			case let .custom(animation):
				self.init(
					duration: (animation.duration ?? defaultDuration) / resolved.speed,
					curve: defaultCompletionCurve.toSwiftUI()
				)
			case .bezier, .fluidSpring, .spring:
				let duration = (resolved.timingCurve.duration ?? defaultDuration) / resolved.speed
				self.init(
					duration: duration,
					timingParameters: AnimationTimingCurveProvider(
						timingCurve: resolved.timingCurve
					)
				)
			}
		} else {
			self.init(duration: defaultDuration, curve: defaultCompletionCurve.toSwiftUI())
		}
	}
}

#endif
