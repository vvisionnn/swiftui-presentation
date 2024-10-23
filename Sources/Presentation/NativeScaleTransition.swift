import SwiftUI

@MainActor
class NativeScaleTransition: UIPercentDrivenInteractiveTransition, UIViewControllerAnimatedTransitioning {
	static let scale: Double = 0.93
	let transitionDuration: Double
	let reverse: Bool

	private var startAlpha: Double { reverse ? 1 : 0 }
	private var endAlpha: Double { reverse ? 0 : 1 }
	private var startScale: Double { reverse ? 1 : Self.scale }
	private var endScale: Double { reverse ? Self.scale : 1 }
	private var startTransform: CGAffineTransform { .init(scaleX: startScale, y: startScale) }
	private var endTransform: CGAffineTransform { .init(scaleX: endScale, y: endScale) }

	@MainActor
	init(
		duration: Double = 0.44,
		reverse: Bool = false
	) {
		self.transitionDuration = duration
		self.reverse = reverse
		super.init()
	}

	@MainActor
	func transitionDuration(
		using transitionContext: (any UIViewControllerContextTransitioning)?
	) -> TimeInterval {
		transitionDuration
	}

	@MainActor
	func animateTransition(
		using transitionContext: any UIViewControllerContextTransitioning
	) {
		guard let toVC = transitionContext.viewController(
			forKey: reverse
				? UITransitionContextViewControllerKey.from
				: UITransitionContextViewControllerKey.to
		), let toView = toVC.view
		else {
			transitionContext.completeTransition(false)
			return
		}

		toView.alpha = startAlpha
		toView.transform = startTransform

		var cover: UIView?
		if !reverse {
			cover = UIView(frame: .zero)
			cover?.backgroundColor = .black.withAlphaComponent(0.15)
			cover?.alpha = startAlpha
			transitionContext.containerView.addSubview(cover!)
			cover?.translatesAutoresizingMaskIntoConstraints = false
			if let cover, let coverParent = cover.superview {
				NSLayoutConstraint.activate([
					cover.topAnchor.constraint(equalTo: coverParent.topAnchor),
					cover.bottomAnchor.constraint(equalTo: coverParent.bottomAnchor),
					cover.leftAnchor.constraint(equalTo: coverParent.leftAnchor),
					cover.rightAnchor.constraint(equalTo: coverParent.rightAnchor),
				])
			}
		}

		transitionContext.containerView.addSubview(toView)
		toView.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			toView.topAnchor.constraint(equalTo: transitionContext.containerView.topAnchor),
			toView.bottomAnchor.constraint(equalTo: transitionContext.containerView.bottomAnchor),
			toView.leftAnchor.constraint(equalTo: transitionContext.containerView.leftAnchor),
			toView.rightAnchor.constraint(equalTo: transitionContext.containerView.rightAnchor),
		])

		UIView.animate(
			withDuration: transitionDuration,
			delay: .zero,
			usingSpringWithDamping: 1,
			initialSpringVelocity: 0.2,
			options: [.overrideInheritedCurve],
			animations: {
				transitionContext.containerView.subviews.first?.alpha = self.endAlpha
				toView.alpha = self.endAlpha
				toView.transform = self.endTransform
			},
			completion: { done in
				guard done else { return }
				transitionContext.completeTransition(done)
			}
		)
	}
}

#if DEBUG && canImport(SwiftUI)
import SwiftUI

struct ScaleParentView: View {
	@State var isChild1Presented = false
	@State var isChild2Presented = false

	var body: some View {
		VStack {
			Text("Parent View")
			Button("Scale Presentation") {
				withAnimation(.smooth) {
					isChild1Presented = true
				}
			}

			Button("Card Presentation") {
				withAnimation(.smooth) {
					isChild2Presented = true
				}
			}
		}
		.presentation(
			//			transition: .custom(
//				options: .init(preferredPresentationBackgroundColor: .clear),
//				ScaleTransition()
//			),
			isPresented: $isChild1Presented
		) {
			ScaleChildView()
		}
		.presentation(
			//			transition: .card,
			isPresented: $isChild2Presented
		) {
			ScaleChildView()
		}
	}
}

struct ScaleChildView: View {
	@Environment(\.dismiss) var dismiss

	var backgroundColor: Color {
		[
			Color(uiColor: .systemMint),
			Color(uiColor: .systemPink),
			Color(uiColor: .systemTeal),
			Color(uiColor: .systemBrown),
		].randomElement()!
	}

	var body: some View {
		VStack {
			Text("Child View")
			Button("Dismiss") {
				dismiss()
			}
		}
		.frame(width: 200, height: 200)
		.background(
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.foregroundStyle(backgroundColor)
		)
	}
}

#Preview {
	ScaleParentView()
}
#endif
