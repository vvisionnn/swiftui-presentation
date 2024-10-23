import Foundation
import UIKit

public enum TransitionType {
	case sheet
	case fullScreen
	case custom(any UIViewControllerTransitioningDelegate)
}

extension TransitionType {
	var transitioningDelegate: UIViewControllerTransitioningDelegate? {
		switch self {
		case .sheet: return nil
		case .fullScreen: return nil
		case let .custom(delegate): return delegate
		}
	}

	var modalPresentationStyle: UIModalPresentationStyle {
		switch self {
		case .sheet: return .automatic
		case .fullScreen: return .overFullScreen
		case .custom: return .custom
		}
	}
}

extension TransitionType {
	@MainActor public static let scale: Self = .custom(NativeScaleTransitioningDelegate())
}
