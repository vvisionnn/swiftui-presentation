import UIKit

extension UIViewController {
	@MainActor
	func presentAsync(_ viewControllerToPresent: UIViewController, animated flag: Bool) async {
		await withCheckedContinuation { continuation in
			self.present(viewControllerToPresent, animated: flag) {
				continuation.resume()
			}
		}
	}

	@MainActor
	func dismissAsync(animated flag: Bool) async {
		await withCheckedContinuation { continuation in
			self.dismiss(animated: flag) {
				continuation.resume()
			}
		}
	}
}
