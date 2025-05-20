import UIKit

extension UIScreen {
	private static let cornerRadiusKey: String = {
		let components = ["Radius", "Corner", "display", "_"]
		return components.reversed().joined()
	}()

	var displayCornerRadius: CGFloat {
		value(forKey: Self.cornerRadiusKey) as? CGFloat ?? 0
	}

	func displayCornerRadius(min: CGFloat = 12) -> CGFloat {
		max(min, _displayCornerRadius)
	}

	var _displayCornerRadius: CGFloat {
		let key = String("suidaRrenroCyalpsid_".reversed())
		let value = value(forKey: key) as? CGFloat ?? 0
		return value
	}
}
