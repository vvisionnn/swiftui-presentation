/// A queue that executes asynchronous tasks enqueued from a nonisolated context in FIFO order.
/// Tasks are guaranteed to begin _and end_ executing in the order in which they are enqueued.
/// Asynchronous tasks sent to this queue work as they would in a `DispatchQueue` type. Attempting to `enqueueAndWait` this queue from a task executing on this queue will result in a deadlock.
final class FIFOQueue: Sendable {
	// MARK: Initialization

	/// Instantiates a FIFO queue.
	/// - Parameter priority: The baseline priority of the tasks added to the asynchronous queue.
	init(priority: TaskPriority? = nil) {
		let (taskStream, taskStreamContinuation) = AsyncStream<@Sendable () async -> Void>.makeStream()
		self.taskStreamContinuation = taskStreamContinuation

		Task.detached(priority: priority) {
			for await task in taskStream {
				await task()
			}
		}
	}

	deinit {
		taskStreamContinuation.finish()
	}

	// MARK: Public

	/// Schedules an asynchronous task for execution and immediately returns.
	/// The scheduled task will not execute until all prior tasks – including suspended tasks – have completed.
	/// - Parameter task: The task to enqueue.
	func enqueue(_ task: @escaping @Sendable () async -> Void) {
		taskStreamContinuation.yield(task)
	}

	/// Schedules an asynchronous task for execution and immediately returns.
	/// The scheduled task will not execute until all prior tasks – including suspended tasks – have completed.
	/// - Parameters:
	///   - isolatedActor: The actor within which the task is isolated.
	///   - task: The task to enqueue.
	func enqueue<ActorType: Actor>(
		on isolatedActor: ActorType,
		_ task: @escaping @Sendable (isolated ActorType) async -> Void
	) {
		taskStreamContinuation.yield { await task(isolatedActor) }
	}

	/// Schedules an asynchronous task and returns after the task is complete.
	/// The scheduled task will not execute until all prior tasks – including suspended tasks – have completed.
	/// - Parameter task: The task to enqueue.
	/// - Returns: The value returned from the enqueued task.
	func enqueueAndWait<T: Sendable>(_ task: @escaping @Sendable () async -> T) async -> T {
		await withUnsafeContinuation { continuation in
			taskStreamContinuation.yield {
				continuation.resume(returning: await task())
			}
		}
	}

	/// Schedules an asynchronous task and returns after the task is complete.
	/// The scheduled task will not execute until all prior tasks – including suspended tasks – have completed.
	/// - Parameters:
	///   - isolatedActor: The actor within which the task is isolated.
	///   - task: The task to enqueue.
	/// - Returns: The value returned from the enqueued task.
	func enqueueAndWait<ActorType: Actor, T: Sendable>(
		on isolatedActor: isolated ActorType,
		_ task: @escaping @Sendable (isolated ActorType) async -> T
	) async -> T {
		await withUnsafeContinuation { continuation in
			taskStreamContinuation.yield {
				continuation.resume(returning: await task(isolatedActor))
			}
		}
	}

	/// Schedules an asynchronous throwing task and returns after the task is complete.
	/// The scheduled task will not execute until all prior tasks – including suspended tasks – have completed.
	/// - Parameter task: The task to enqueue.
	/// - Returns: The value returned from the enqueued task.
	func enqueueAndWait<T: Sendable>(_ task: @escaping @Sendable () async throws -> T) async throws -> T {
		try await withUnsafeThrowingContinuation { continuation in
			taskStreamContinuation.yield {
				do {
					continuation.resume(returning: try await task())
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}

	/// Schedules an asynchronous throwing task and returns after the task is complete.
	/// The scheduled task will not execute until all prior tasks – including suspended tasks – have completed.
	/// - Parameters:
	///   - isolatedActor: The actor within which the task is isolated.
	///   - task: The task to enqueue.
	/// - Returns: The value returned from the enqueued task.
	func enqueueAndWait<ActorType: Actor, T: Sendable>(
		on isolatedActor: isolated ActorType,
		_ task: @escaping @Sendable (isolated ActorType) async throws -> T
	) async throws -> T {
		try await withUnsafeThrowingContinuation { continuation in
			taskStreamContinuation.yield {
				do {
					continuation.resume(returning: try await task(isolatedActor))
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}

	// MARK: Private

	private let taskStreamContinuation: AsyncStream<@Sendable () async -> Void>.Continuation
}
