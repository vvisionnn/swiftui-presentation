//
//  UIView+Extensions.swift
//  swiftui-presentation
//
//  Created by Andy Wen on 2024/10/21.
//


import UIKit

extension UIView {
	var viewController: UIViewController? {
		_viewController
	}
	
	public var _viewController: UIViewController? {
		var responder: UIResponder? = next
		while responder != nil, !(responder is UIViewController) {
			responder = responder?.next
		}
		return responder as? UIViewController
	}
}
