import Combine
import SwiftUI

struct PresentationBridge<Destination: View>: UIViewRepresentable {
	@WeakState var presentingViewController: UIViewController?
	@Binding var isPresented: Bool
	var transition: TransitionType
	var destination: Destination

	func makeUIView(context: Context) -> ViewControllerReader {
		let coordinator = context.coordinator
		return .init { [weak coordinator] presentingViewController in
			coordinator?.presentingViewController = presentingViewController
			self.presentingViewController = presentingViewController
		}
	}

	func updateUIView(_ uiView: ViewControllerReader, context: Context) {
		guard context.coordinator.presentingViewController != nil else { return }
		context.coordinator.isPresented = $isPresented
		context.coordinator.destination = isPresented ? destination : context.coordinator.destination
		context.coordinator.transition = transition
		context.coordinator.presentationState.send(isPresented)
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(
			isPresented: $isPresented,
			transition: transition,
			destination: destination
		)
	}
}

extension PresentationBridge {
	// TODO: Sendable conformances
	// TODO: add transaction support instead of constant animation
	class Coordinator: NSObject, UIViewControllerPresentationDelegate, @unchecked Sendable {
		weak var presentingViewController: UIViewController?
		let presentationState: CurrentValueSubject<Bool, Never> = .init(false)
		private var subscriptions: Set<AnyCancellable> = .init()
		private let presentationQueue: FIFOQueue = .init(priority: .userInitiated)
		private var presentedViewController: UIViewController?
		var destination: Destination
		var isPresented: Binding<Bool>
		var transition: TransitionType

		deinit { subscriptions.forEach { $0.cancel() } }
		public init(
			isPresented: Binding<Bool>,
			transition: TransitionType,
			destination: Destination
		) {
			self.isPresented = isPresented
			self.transition = transition
			self.destination = destination
			super.init()
			presentationState
				.removeDuplicates()
				.withPrevious(false)
				.receive(on: DispatchQueue.main)
				.filter { [weak self] _ in self?.presentingViewController != nil }
				.sink { [weak self] prev, curr in
					self?.handlePresentationStatusChange(prev: prev, curr: curr)
				}
				.store(in: &subscriptions)
		}

		private func handlePresentationStatusChange(prev: Bool, curr: Bool) {
			guard prev != curr, presentingViewController != nil else { return }
			presentationQueue.enqueue { [weak self] in
				guard let self else { return }
				switch (prev, curr) {
				case (false, false), (true, true):
					return
				case (false, true):
					if let presentedViewController = await presentingViewController?.presentedViewController {
						await presentedViewController.dismissAsync(animated: true)
					}
					let presentedViewController = await UIHostingController(rootView: destination)
					await MainActor.run {
						switch self.transition {
						case .sheet:
							presentedViewController.modalPresentationStyle = .pageSheet
						case .fullScreen:
							presentedViewController.modalPresentationStyle = .overFullScreen
						case let .custom(transitioningDelegate):
							presentedViewController.modalPresentationStyle = self.transition.modalPresentationStyle
							presentedViewController.transitioningDelegate = transitioningDelegate
							presentedViewController.presentationDelegate = self
						}
						presentedViewController.view.backgroundColor = .clear
					}
					self.presentedViewController = presentedViewController
					await presentingViewController?.presentAsync(presentedViewController, animated: true)
				case (true, false):
					guard presentedViewController != nil else { return }
					defer { self.presentedViewController = nil }
					await presentingViewController?.dismissAsync(animated: true)
					await MainActor.run {
						self.presentedViewController?.presentationDelegate = nil
					}
				}
			}
		}

		func viewControllerDidDismiss(_ presentingViewController: UIViewController?, animated: Bool) {
			var transaction = Transaction()
			transaction.disablesAnimations = true
			withTransaction(transaction) {
				self.isPresented.wrappedValue = false
			}

			// Dismiss already handled by the presentation controller below
			if let presentingViewController {
				// presentingViewController.setNeedsStatusBarAppearanceUpdate(animated: animated)
				presentingViewController.fixSwiftUIHitTesting()
			}
		}
	}
}
