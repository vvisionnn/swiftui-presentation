import Combine

extension Publisher {
	func withPrevious(
		_ initialPreviousValue: Output
	) -> AnyPublisher<(
		previous: Output,
		current: Output
	), Failure> {
		scan((initialPreviousValue, initialPreviousValue)) { ($0.1, $1) }.eraseToAnyPublisher()
	}
}
