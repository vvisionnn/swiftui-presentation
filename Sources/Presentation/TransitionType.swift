import Foundation
import UIKit

public enum TransitionType {
	case custom(any UIViewControllerTransitioningDelegate)
}

extension TransitionType {
	var transitioningDelegate: UIViewControllerTransitioningDelegate? {
		switch self {
		case let .custom(delegate): return delegate
		}
	}

	var modalPresentationStyle: UIModalPresentationStyle {
		switch self {
		case .custom: return .custom
		}
	}
}

extension TransitionType {
	@MainActor public static let scale: Self = .custom(NativeScaleTransitioningDelegate())
	@MainActor public static let interactiveFullSheet: Self = .custom(SlideTransitioningDelegate())
}
