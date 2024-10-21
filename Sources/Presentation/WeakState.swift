import Combine
import SwiftUI

@propertyWrapper
@MainActor @preconcurrency
struct WeakState<Value: AnyObject>: DynamicProperty {
	@usableFromInline
	var storage: StateObject<Storage>

	@inlinable
	@preconcurrency
	@MainActor
	init(wrappedValue thunk: @autoclosure @escaping () -> Value?) {
		self.storage = StateObject<Storage>(wrappedValue: { Storage(value: thunk()) }())
	}

	@preconcurrency
	@MainActor
	var wrappedValue: Value? {
		get { storage.wrappedValue.value }
		nonmutating set { storage.wrappedValue.value = newValue }
	}

	@preconcurrency
	@MainActor
	var projectedValue: Binding<Value?> {
		storage.projectedValue.value
	}
}

extension WeakState {
	@usableFromInline
	@preconcurrency
	@MainActor
	class Storage: ObservableObject {
		weak var value: Value? {
			didSet {
				guard oldValue !== value else { return }
				objectWillChange.send()
			}
		}

		@usableFromInline
		init(value: Value?) {
			self.value = value
		}
	}
}
