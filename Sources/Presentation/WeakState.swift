import Combine
import SwiftUI

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
@propertyWrapper
@MainActor @preconcurrency
struct WeakState<Value: AnyObject>: DynamicProperty {
	@usableFromInline
	@MainActor @preconcurrency
	class Storage: ObservableObject {
		weak var value: Value? {
			didSet {
				if oldValue !== value {
					objectWillChange.send()
				}
			}
		}

		@usableFromInline
		init(value: Value?) { self.value = value }
	}

	@usableFromInline
	var storage: StateObject<Storage>

	@inlinable
	@MainActor @preconcurrency
	init(wrappedValue thunk: @autoclosure @escaping () -> Value?) {
		self.storage = StateObject<Storage>(wrappedValue: { Storage(value: thunk()) }())
	}

	@MainActor @preconcurrency
	var wrappedValue: Value? {
		get { storage.wrappedValue.value }
		nonmutating set { storage.wrappedValue.value = newValue }
	}

	@MainActor @preconcurrency
	var projectedValue: Binding<Value?> {
		storage.projectedValue.value
	}
}
