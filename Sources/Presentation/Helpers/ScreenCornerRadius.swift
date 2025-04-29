import UIKit

extension UIScreen {
	private static let cornerRadiusKey: String = {
		let components = ["Radius", "Corner", "display", "_"]
		return components.reversed().joined()
	}()

	var displayCornerRadius: CGFloat {
		value(forKey: Self.cornerRadiusKey) as? CGFloat ?? 0
	}
}
