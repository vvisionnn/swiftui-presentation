import Combine
import SwiftUI

struct PresentationWrapper<Destination: View>: UIViewRepresentable {
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
		context.coordinator.destination = destination
		context.coordinator.presentationState.send(isPresented)
	}

	func makeCoordinator() -> Coordinator {
		.init(destination: destination)
	}

	// TODO: Sendable conformances
	// TODO: add transaction support instead of constant animation
	class Coordinator: NSObject, @unchecked Sendable {
		weak var presentingViewController: UIViewController?
		let presentationState: CurrentValueSubject<Bool, Never> = .init(false)
		private var subscriptions: Set<AnyCancellable> = .init()
		private let presentationQueue: FIFOQueue = .init(priority: .userInitiated)
		private var presentedViewController: UIViewController?
		var destination: Destination

		deinit { subscriptions.forEach { $0.cancel() } }
		public init(destination: Destination) {
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
					self.presentedViewController = presentedViewController
					await presentingViewController?.present(presentedViewController, animated: true)
				case (true, false):
					guard presentedViewController != nil else { return }
					defer { presentedViewController = nil }
					await presentingViewController?.dismiss(animated: true)
				}
			}
		}
	}
}

extension Publisher {
	fileprivate func withPrevious() -> AnyPublisher<(previous: Output?, current: Output), Failure> {
		scan((Output?, Output)?.none) { ($0?.1, $1) }
			.compactMap { $0 }
			.eraseToAnyPublisher()
	}

	fileprivate func withPrevious(
		_ initialPreviousValue: Output
	) -> AnyPublisher<(
		previous: Output,
		current: Output
	), Failure> {
		scan((initialPreviousValue, initialPreviousValue)) { ($0.1, $1) }.eraseToAnyPublisher()
	}
}

extension UIViewController {
	@MainActor
	func present(_ viewControllerToPresent: UIViewController, animated flag: Bool) async {
		await withCheckedContinuation { continuation in
			self.present(viewControllerToPresent, animated: flag) {
				continuation.resume()
			}
		}
	}

	@MainActor
	func dismiss(animated flag: Bool) async {
		await withCheckedContinuation { continuation in
			self.dismiss(animated: flag) {
				continuation.resume()
			}
		}
	}
}

@frozen
public struct PresentationModifier<Destination: View>: ViewModifier {
	var isPresented: Binding<Bool>
	var destination: Destination

	public init(
		isPresented: Binding<Bool>,
		destination: Destination
	) {
		self.isPresented = isPresented
		self.destination = destination
	}

	public func body(content: Content) -> some View {
		content.background(
			PresentationWrapper(
				isPresented: isPresented,
				destination: destination
			)
		)
	}
}

extension View {
	public func presentation<T: Sendable, Destination: View>(
		item: Binding<T?>,
		@ViewBuilder destination: (T) -> Destination
	) -> some View {
		presentation(isPresented: item.isNotNil()) {
			if let val = item.wrappedValue {
				destination(returningLastNonNilValue({ item.wrappedValue }, default: val)())
			} else {
				EmptyView()
			}
		}
	}

	public func presentation<Destination: View>(
		isPresented: Binding<Bool>,
		@ViewBuilder destination: () -> Destination
	) -> some View {
		modifier(
			PresentationModifier(
				isPresented: isPresented,
				destination: destination()
			)
		)
	}
}

func returningLastNonNilValue<B>(_ f: @escaping () -> B?, default: B) -> () -> B {
	var lastWrapped: B = `default`
	return {
		lastWrapped = f() ?? lastWrapped
		return lastWrapped
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
							DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
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
