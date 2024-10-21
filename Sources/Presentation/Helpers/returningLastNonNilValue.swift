func returningLastNonNilValue<B>(_ f: @escaping () -> B?, default: B) -> () -> B {
	var lastWrapped: B = `default`
	return {
		lastWrapped = f() ?? lastWrapped
		return lastWrapped
	}
}
