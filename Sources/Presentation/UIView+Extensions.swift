import UIKit

extension UIView {
	var viewController: UIViewController? {
		var responder: UIResponder? = next
		while responder != nil, !(responder is UIViewController) {
			responder = responder?.next
		}
		return responder as? UIViewController
	}
}
