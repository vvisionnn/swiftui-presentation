import SwiftUI

@frozen
public struct PresentationModifier<Destination: View>: ViewModifier {
	var isPresented: Binding<Bool>
	var transition: TransitionType
	var destination: Destination

	public init(isPresented: Binding<Bool>, transition: TransitionType, destination: Destination) {
		self.isPresented = isPresented
		self.destination = destination
		self.transition = transition
	}

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
	public func presentation<T: Sendable, Destination: View>(
		item: Binding<T?>,
		transition: TransitionType = .sheet,
		@ViewBuilder destination: (T) -> Destination
	) -> some View {
		presentation(isPresented: item.isNotNil(), transition: transition) {
			if let val = item.wrappedValue {
				destination(returningLastNonNilValue({ item.wrappedValue }, default: val)())
			} else {
				EmptyView()
			}
		}
	}

	public func presentation<Destination: View>(
		isPresented: Binding<Bool>,
		transition: TransitionType = .sheet,
		@ViewBuilder destination: () -> Destination
	) -> some View {
		modifier(
			PresentationModifier(
				isPresented: isPresented,
				transition: transition,
				destination: destination()
			)
		)
	}
}
