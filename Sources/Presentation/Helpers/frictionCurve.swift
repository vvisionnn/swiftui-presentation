import UIKit

func frictionCurve(
	_ value: CGFloat,
	distance: CGFloat = 200,
	coefficient: CGFloat = 0.3
) -> CGFloat {
	if value < 0 {
		return -frictionCurve(abs(value), distance: distance, coefficient: coefficient)
	}
	return (1.0 - (1.0 / ((value * coefficient / distance) + 1.0))) * distance
}
