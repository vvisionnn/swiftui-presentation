import os.log
import SwiftUI

/// A protocol for defining a transform for a `Binding`
public protocol BindingTransform: Sendable {
	associatedtype Input
	associatedtype Output

	func get(_ value: Input) -> Output
	func set(_ newValue: Output, oldValue: @autoclosure () -> Input) throws -> Input
}

extension Binding where Value: Sendable {
	/// Projects a `Binding` with the `transform`
	@inlinable
	public func projecting<Transform: BindingTransform>(
		_ transform: Transform
	) -> Binding<Transform.Output> where Transform.Input == Value {
		Binding<Transform.Output> {
			transform.get(wrappedValue)
		} set: { newValue, transaction in
			do {
				self.transaction(transaction).wrappedValue = try transform.set(newValue, oldValue: wrappedValue)
			} catch {
				os_log(
					.error,
					log: .default,
					"Projection %{public}@ failed with error: %{public}@",
					String(describing: Self.self),
					error.localizedDescription
				)
			}
		}
	}
}

@frozen
public struct IsNotNilTransform<Input>: BindingTransform {
	@inlinable
	public init() {}

	public func get(_ value: Input?) -> Bool {
		value != nil
	}

	public func set(_ newValue: Output, oldValue: @autoclosure () -> Input?) throws -> Input? {
		if !newValue {
			return nil
		}
		return oldValue()
	}
}

extension Binding where Value: Sendable {
	/// A ``BindingTransform`` that transforms the value to `true` when not `nil`
	@inlinable
	public func isNotNil<Wrapped>() -> Binding<Bool> where Wrapped? == Value {
		projecting(IsNotNilTransform())
	}
}
