#if os(iOS)

import SwiftUI
import UIKit

@frozen
public struct TransitionReaderProxy {
	/// The progress state of the transition from 0 to 1 where 1 is fully presented.
	public var progress: CGFloat
	public var isTransitioning: Bool

	@usableFromInline
	init(progress: CGFloat, isTransitioning: Bool) {
		self.progress = progress
		self.isTransitioning = isTransitioning
	}
}

@frozen
public struct TransitionReader<Content: View>: View {
	public typealias Proxy = TransitionReaderProxy

	@usableFromInline
	var content: (Proxy) -> Content

	@State var proxy = Proxy(progress: 0, isTransitioning: false)

	@inlinable
	public init(
		@ViewBuilder content: @escaping (Proxy) -> Content
	) {
		self.content = content
	}

	public var body: some View {
		content(proxy)
			.background(
				TransitionReaderAdapter(
					progress: $proxy.progress,
					isTransitioning: $proxy.isTransitioning
				)
			)
	}
}

private struct TransitionReaderAdapter: UIViewRepresentable {
	var progress: Binding<CGFloat>
	var isTransitioning: Binding<Bool>

	func makeUIView(context: Context) -> ViewControllerReader {
		let uiView = ViewControllerReader { vc in
			context.coordinator.presentingViewController = vc
		}
		return uiView
	}

	func updateUIView(_ uiView: ViewControllerReader, context: Context) {}

	func makeCoordinator() -> Coordinator {
		Coordinator(progress: progress, isTransitioning: isTransitioning)
	}

	final class Coordinator: NSObject {
		let progress: Binding<CGFloat>
		let isTransitioning: Binding<Bool>
		private var trackedViewControllers = NSHashTable<UIViewController>.weakObjects()
		private weak var transitionCoordinator: (any UIViewControllerTransitionCoordinator)?
		private weak var displayLink: CADisplayLink?

		@MainActor
		weak var presentingViewController: UIViewController? {
			didSet {
				guard oldValue != presentingViewController else { return }
				presentingViewControllerDidChange()
			}
		}

		deinit { presentingViewController = nil }
		init(progress: Binding<CGFloat>, isTransitioning: Binding<Bool>) {
			self.progress = progress
			self.isTransitioning = isTransitioning
		}

		@MainActor
		private func reset() {
			defer { trackedViewControllers.removeAllObjects() }
			trackedViewControllers.allObjects.forEach { viewController in
				viewController.swizzle_beginAppearanceTransition(nil)
				viewController.swizzle_endAppearanceTransition(nil)
			}
		}

		@MainActor
		private func presentingViewControllerDidChange() {
			reset()
			if let presentingViewController {
				trackedViewControllers.add(presentingViewController)

				if let parent = presentingViewController.parent {
					trackedViewControllers.add(parent)
				}
			}

			for viewController in trackedViewControllers.allObjects {
				viewController.swizzle_beginAppearanceTransition { [unowned self] in
					transitionCoordinatorDidChange()
				}
				viewController.swizzle_endAppearanceTransition { [unowned self] in
					transitionCoordinatorDidChange()
				}
			}
			transitionCoordinatorDidChange()
		}

		@MainActor
		private func transitionCoordinatorDidChange() {
			if let presentingViewController = presentingViewController {
				if let transitionCoordinator = presentingViewController.transitionCoordinator, displayLink == nil {
					debugPrint("isInteractive: \(transitionCoordinator.isInteractive)")
					if transitionCoordinator.isInteractive {
						let displayLink = CADisplayLink(target: self, selector: #selector(onClockTick(displayLink:)))
						displayLink.add(to: .current, forMode: .common)
						self.displayLink = displayLink
						self.transitionCoordinator = transitionCoordinator
					} else {
						transitionDidChange(transitionCoordinator)
					}

					transitionCoordinator.notifyWhenInteractionChanges { [weak self] ctx in
						self?.transitionDidChange(ctx)
					}
				} else if presentingViewController.isBeingPresented || presentingViewController.isBeingDismissed {
					let isPresented = presentingViewController.isBeingPresented
					let transaction = Transaction(animation: nil)
					debugPrint("isPresented: \(isPresented) progress: \(isPresented ? 1 : 0)")
					withTransaction(transaction) {
						self.progress.wrappedValue = isPresented ? 1 : 0
					}
				}
			} else {
				displayLink?.invalidate()
				progress.wrappedValue = 0
			}
		}

		@objc @MainActor
		private func onClockTick(displayLink: CADisplayLink) {
			if let transitionCoordinator = transitionCoordinator {
				transitionDidChange(transitionCoordinator)
			} else {
				displayLink.invalidate()
				isTransitioning.wrappedValue = false
			}
		}

		@MainActor
		private func transitionDidChange(_ transitionCoordinator: any UIViewControllerTransitionCoordinatorContext) {
			let from = transitionCoordinator.viewController(forKey: .from)
			let isPresenting = !trackedViewControllers.contains(from)
			if transitionCoordinator.isInteractive {
				let percentComplete = isPresenting
					? transitionCoordinator.percentComplete
					: 1 - transitionCoordinator.percentComplete
				var transaction = Transaction()
				transaction.isContinuous = true
				let isTransitioning = !transitionCoordinator.isCancelled
					&& transitionCoordinator.percentComplete > 0
					&& transitionCoordinator.percentComplete < 1
				withTransaction(transaction) {
					progress.wrappedValue = percentComplete
					self.isTransitioning.wrappedValue = isTransitioning
				}
			} else {
				let newValue: CGFloat = transitionCoordinator.isCancelled ? isPresenting ? 0 : 1 : isPresenting ? 1 : 0
				var transaction = Transaction(animation: nil)
				transaction.disablesAnimations = true
				if transitionCoordinator.isAnimated {
					let duration = transitionCoordinator.transitionDuration == 0 ? 0.35 : transitionCoordinator.transitionDuration
					let animation = transitionCoordinator.completionCurve.toSwiftUI(duration: duration)
					transaction.animation = animation
					transaction.disablesAnimations = false
				}
				let isTransitioning = transitionCoordinator.percentComplete > 0 && transitionCoordinator.percentComplete < 1
				withTransaction(transaction) {
					self.progress.wrappedValue = newValue
					if self.isTransitioning.wrappedValue != isTransitioning {
						self.isTransitioning.wrappedValue = isTransitioning
					}
				}
			}
		}
	}
}

extension UIViewController {
	private static var beginAppearanceTransitionKey: Bool = false

	struct BeginAppearanceTransition {
		var value: () -> Void
	}

	func swizzle_beginAppearanceTransition(_ transition: (() -> Void)?) {
		let original = #selector(UIViewController.beginAppearanceTransition(_:animated:))
		let swizzled = #selector(UIViewController.swizzled_beginAppearanceTransition(_:animated:))

		if !Self.beginAppearanceTransitionKey {
			Self.beginAppearanceTransitionKey = true

			if let originalMethod = class_getInstanceMethod(Self.self, original),
			   let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzled) {
				method_exchangeImplementations(originalMethod, swizzledMethod)
			}
		}

		if let transition {
			let box = ObjCBox(value: BeginAppearanceTransition(value: transition))
			objc_setAssociatedObject(self, &Self.beginAppearanceTransitionKey, box, .OBJC_ASSOCIATION_RETAIN)
		} else {
			objc_setAssociatedObject(self, &Self.beginAppearanceTransitionKey, nil, .OBJC_ASSOCIATION_RETAIN)
		}
	}

	@objc
	func swizzled_beginAppearanceTransition(_ isAppearing: Bool, animated: Bool) {
		if let box = objc_getAssociatedObject(self, &Self.beginAppearanceTransitionKey) as? ObjCBox<BeginAppearanceTransition> {
			box.value.value()
		}

		typealias BeginAppearanceTransitionMethod = @convention(c) (NSObject, Selector, Bool, Bool) -> Void
		let swizzled = #selector(UIViewController.swizzled_beginAppearanceTransition(_:animated:))
		unsafeBitCast(method(for: swizzled), to: BeginAppearanceTransitionMethod.self)(self, swizzled, isAppearing, animated)
	}

	private static var endAppearanceTransitionKey: Bool = false

	struct EndAppearanceTransition {
		var value: () -> Void
	}

	func swizzle_endAppearanceTransition(_ transition: (() -> Void)?) {
		let original = #selector(UIViewController.endAppearanceTransition)
		let swizzled = #selector(UIViewController.swizzled_endAppearanceTransition)

		if !Self.endAppearanceTransitionKey {
			Self.endAppearanceTransitionKey = true

			if let originalMethod = class_getInstanceMethod(Self.self, original),
			   let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzled) {
				method_exchangeImplementations(originalMethod, swizzledMethod)
			}
		}

		if let transition {
			let box = ObjCBox(value: EndAppearanceTransition(value: transition))
			objc_setAssociatedObject(self, &Self.endAppearanceTransitionKey, box, .OBJC_ASSOCIATION_RETAIN)
		} else {
			objc_setAssociatedObject(self, &Self.endAppearanceTransitionKey, nil, .OBJC_ASSOCIATION_RETAIN)
		}
	}

	@objc
	func swizzled_endAppearanceTransition() {
		if let box = objc_getAssociatedObject(self, &Self.endAppearanceTransitionKey) as? ObjCBox<EndAppearanceTransition> {
			box.value.value()
		}

		typealias EndAppearanceTransitionMethod = @convention(c) (NSObject, Selector) -> Void
		let swizzled = #selector(UIViewController.swizzled_endAppearanceTransition)
		unsafeBitCast(method(for: swizzled), to: EndAppearanceTransitionMethod.self)(self, swizzled)
	}
}

extension UIView.AnimationCurve {
	func toSwiftUI(duration: TimeInterval) -> Animation {
		switch self {
		case .linear:
			return .linear(duration: duration)
		case .easeIn:
			return .easeIn(duration: duration)
		case .easeOut:
			return .easeOut(duration: duration)
		case .easeInOut:
			return .easeInOut(duration: duration)
		@unknown default:
			return .default
		}
	}
}

#if DEBUG
struct TransitionReaderParentView: View {
	@State var path: [String] = []
	@State var progress: CGFloat = 0

	var body: some View {
		NavigationStack(path: $path) {
			VStack {
				NavigationLink("Go to screen 1", value: "1")
				NavigationLink("Go to screen 2", value: "2")
				NavigationLink("Go to screen 3", value: "3")
				NavigationLink("Go to screen 4", value: "4")
			}.navigationDestination(for: String.self) { value in
				TransitionReader { proxy in
					Text("[\(proxy.progress)] This is screen number \(value)")
						.background(proxy.isTransitioning ? Color.mint.opacity(proxy.progress) : Color.pink.opacity(proxy.progress))
						.onChange(of: proxy.progress) { newValue in
							progress = newValue
						}
				}
			}
			.background(Color.mint.gradient.opacity(progress))
		}
	}
}

#Preview(body: {
	TransitionReaderParentView()
})
#endif
#endif
