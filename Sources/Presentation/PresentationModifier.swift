import SwiftUI

@frozen
public struct PresentationModifier<Destination: View>: ViewModifier {
	var isPresented: Binding<Bool>
	var transition: TransitionType
	var destination: () -> Destination

	public init(
		isPresented: Binding<Bool>,
		transition: TransitionType,
		@ViewBuilder destination: @escaping () -> Destination
	) {
		self.isPresented = isPresented
		self.destination = destination
		self.transition = transition
	}

	@MainActor
	public func body(content: Content) -> some View {
		content.background(
			PresentationBridge(
				isPresented: isPresented,
				transition: transition,
				destination: destination
			)
		)
	}
}

extension View {
	@_disfavoredOverload
	public func presentation<T: Sendable, Destination: View>(
		item: Binding<T?>,
		transition: TransitionType? = nil,
		@ViewBuilder destination: @escaping (T) -> Destination
	) -> some View {
		presentation(
			isPresented: item.isNotNil(),
			transition: transition ?? .interactiveFullSheet
		) {
			if let val = item.wrappedValue {
				destination(returningLastNonNilValue({ item.wrappedValue }, default: val)())
			} else {
				EmptyView()
			}
		}
	}

	public func presentation<Destination: View>(
		isPresented: Binding<Bool>,
		transition: TransitionType? = nil,
		@ViewBuilder destination: @escaping () -> Destination
	) -> some View {
		modifier(
			PresentationModifier(
				isPresented: isPresented,
				transition: transition ?? .interactiveFullSheet,
				destination: destination
			)
		)
	}
}
