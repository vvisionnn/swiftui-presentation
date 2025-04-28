import UIKit

@MainActor
public class FrameRateRequest {
	private let frameRateRange: CAFrameRateRange
	private let duration: Double

	/// Prepares your frame rate request parameters.
	public init(preferredFrameRate: Float, duration: Double) {
		self.frameRateRange = CAFrameRateRange(
			minimum: 30,
			maximum: Float(UIScreen.main.maximumFramesPerSecond),
			preferred: preferredFrameRate
		)
		self.duration = duration
	}

	/// Perform frame rate request.
	public func perform() {
		let displayLink = CADisplayLink(target: self, selector: #selector(dummyFunction))
		displayLink.preferredFrameRateRange = frameRateRange
		displayLink.add(to: .main, forMode: .common)
		DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
			displayLink.remove(from: .main, forMode: .common)
		}
	}

	@objc private func dummyFunction() {}
}
