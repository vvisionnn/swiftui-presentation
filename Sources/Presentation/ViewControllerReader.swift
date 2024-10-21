import SwiftUI

final class ViewControllerReader: UIView {
	let presentingViewControllerReader: (UIViewController?) -> Void

	init(presentingViewControllerReader: @escaping (UIViewController?) -> Void) {
		self.presentingViewControllerReader = presentingViewControllerReader
		super.init(frame: .zero)
		isHidden = true
		alpha = 0
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func didMoveToWindow() {
		super.didMoveToWindow()
		CATransaction.begin()
		CATransaction.setCompletionBlock { [weak self] in
			guard let self = self else { return }
			presentingViewControllerReader(viewController)
		}
		CATransaction.commit()
	}
}
