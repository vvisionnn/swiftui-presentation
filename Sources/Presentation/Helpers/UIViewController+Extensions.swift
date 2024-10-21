import UIKit

extension UIViewController {
	@MainActor
	func present(_ viewControllerToPresent: UIViewController, animated flag: Bool) async {
		await withCheckedContinuation { continuation in
			self.present(viewControllerToPresent, animated: flag) {
				continuation.resume()
			}
		}
	}

	@MainActor
	func dismiss(animated flag: Bool) async {
		await withCheckedContinuation { continuation in
			self.dismiss(animated: flag) {
				continuation.resume()
			}
		}
	}
}
