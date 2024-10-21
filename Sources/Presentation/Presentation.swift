import Combine
import SwiftUI

struct PresentationBridge<Destination: View>: UIViewRepresentable {
	@Binding var isPresented: Bool
	@WeakState var presentingViewController: UIViewController?
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
		context.coordinator.destination = destination
		context.coordinator.presentationState.send(isPresented)
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(
			isPresented: $isPresented,
			destination: destination
		)
	}

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

		deinit { subscriptions.forEach { $0.cancel() } }
		public init(isPresented: Binding<Bool>, destination: Destination) {
			self.isPresented = isPresented
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
						await presentedViewController.dismiss(animated: true)
					}
					let presentedViewController = await UIHostingController(rootView: destination)
					await MainActor.run {
						presentedViewController.presentationDelegate = self
					}
					self.presentedViewController = presentedViewController
					await presentingViewController?.present(presentedViewController, animated: true)
				case (true, false):
					guard presentedViewController != nil else { return }
					defer { presentedViewController = nil }
					await presentingViewController?.dismiss(animated: true)
					await MainActor.run {
						presentedViewController?.presentationDelegate = nil
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

#if DEBUG
struct ParentView: View {
	@State private var isChild1Presented = true
	@State private var isChild2Presented = false

	// The problem is, by design, view is following the state change
	// so after we click the button, the child 1 should be dismiss
	// and child 2 should be presented then dismiss
	// but the behavior is, child 1 is dismissed, child 2 is presented
	// NOTE: replace the `.presentation` with SwiftUI native `.sheet` there is no problem
	var body: some View {
		Rectangle()
			.foregroundStyle(Color.mint.gradient)
			.ignoresSafeArea()
			.onChange(of: isChild2Presented) { val in
				debugPrint("asd \(isChild2Presented)")
			}
			.overlay(content: {
				VStack {
					Button(action: {
						withAnimation(.spring) {
							isChild1Presented = true
						}
					}) {
						Text("Present 1")
					}

					Button(action: {
						withAnimation(.spring) {
							isChild2Presented = true
						}
					}) {
						Text("Present 2")
					}
				}
			})
			.presentation(isPresented: $isChild1Presented) {
				ChildView()
					.overlay {
						Button(action: {
							debugPrint("dismissing child1 and present child2")
							withAnimation(.spring) {
								isChild1Presented = false
								isChild2Presented = true
							}

							// after a very quick action finished (mock running time 200ms)
							DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
								debugPrint("dismissing child2")
								withAnimation(.spring) {
									isChild2Presented = false
								}
							}
						}) {
							Text("Dismiss then present child2")
								.foregroundStyle(Color.white)
								.font(.system(.headline))
						}
					}
			}
			.presentation(isPresented: $isChild2Presented) {
				ChildView()
			}
	}
}

struct ChildView: View {
	var timePublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
	@State var currentTime: Date = .init()

	var body: some View {
		Rectangle()
			.foregroundStyle(Color.pink.gradient)
			.ignoresSafeArea()
			.onReceive(timePublisher) { _ in currentTime = Date() }
			.overlay(alignment: .top) {
				Text("Current time: \(currentTime.description)")
					.foregroundStyle(Color.white)
					.font(.system(.headline))
					.padding(.top)
			}
	}
}

#Preview {
	ParentView()
}
#endif
