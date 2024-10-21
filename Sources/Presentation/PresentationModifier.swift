import SwiftUI

@frozen
public struct PresentationModifier<Destination: View>: ViewModifier {
	var isPresented: Binding<Bool>
	var destination: Destination

	public init(isPresented: Binding<Bool>, destination: Destination) {
		self.isPresented = isPresented
		self.destination = destination
	}

	public func body(content: Content) -> some View {
		content.background(
			PresentationBridge(
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
