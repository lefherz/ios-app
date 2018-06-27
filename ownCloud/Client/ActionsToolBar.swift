//
//  ActionsToolBar.swift
//  ownCloud
//
//  Created by Pablo Carrascal on 27/06/2018.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
* Copyright (C) 2018, ownCloud GmbH.
*
* This code is covered by the GNU Public License Version 3.
*
* For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
* You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
*
*/

import UIKit

import UIKit

protocol ActionsToolBarDelegate: class {

	func actionsToolBar(_ toolbar: ActionsToolBar, copyButtonPressed: UIBarButtonItem?)

	func actionsToolBar(_ toolbar: ActionsToolBar, availableOfflineButtonPressed: UIBarButtonItem?)

	func actionsToolBar(_ toolbar: ActionsToolBar, shareButtonPressed: UIBarButtonItem?)

	func actionsToolBar(_ toolbar: ActionsToolBar, deleteButtonPressed: UIBarButtonItem?)
}

enum ActionsToolBarAction {
	case copy
	case availableOffline
	case share
	case delete
}

class ActionsToolBar: UIToolbar, Themeable {

	weak var actionsDelegate: ActionsToolBarDelegate?

	// MARK: - Bar buttons

	var copyButton: UIBarButtonItem?
	var availableOfflineButton: UIBarButtonItem?
	var shareButton: UIBarButtonItem?
	var deleteButton: UIBarButtonItem?

	// MARK: - Init & deInit

	override init(frame: CGRect) {
		super.init(frame: frame)

		Theme.shared.register(client: self)
		self.accessibilityIdentifier = "client-actions-tool-bar"

		copyButton = UIBarButtonItem(barButtonSystemItem: .organize, target: self, action: #selector(copyButtonAction))
		copyButton?.accessibilityIdentifier = "client-actions-tool-bar-copy"

		availableOfflineButton = UIBarButtonItem(barButtonSystemItem: .bookmarks, target: self, action: #selector(availableOfflineButtonAction))
		availableOfflineButton?.accessibilityIdentifier = "client-actions-tool-bar-available-offline"

		shareButton = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareButtonAction))
		shareButton?.accessibilityIdentifier = "client-actions-tool-bar-share"

		deleteButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deleteButtonAction))
		deleteButton?.accessibilityIdentifier = "client-actions-tool-bar-delete"

		self.setItems([copyButton!,
					   UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
					   availableOfflineButton!,
					   UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
					   shareButton!,
					   UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
					   deleteButton!],
					  animated: false)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		Theme.shared.unregister(client: self)
	}

	// MARK: - Actions

	@objc private func copyButtonAction() {
		actionsDelegate?.actionsToolBar(self, copyButtonPressed: deleteButton)
	}

	@objc private func availableOfflineButtonAction() {
		actionsDelegate?.actionsToolBar(self, availableOfflineButtonPressed: availableOfflineButton)
	}

	@objc private func shareButtonAction() {
		actionsDelegate?.actionsToolBar(self, shareButtonPressed: shareButton)
	}

	@objc private func deleteButtonAction() {
		actionsDelegate?.actionsToolBar(self, deleteButtonPressed: deleteButton)
	}

	// MARK: - Theme support

	func applyThemeCollection(theme: Theme, collection: ThemeCollection, event: ThemeEvent) {
		self.applyThemeCollection(collection)
	}

	// MARK: - Enabling & disabling buttons

	func enableAll() {
		enable(actions: [.copy, .availableOffline, .share, .delete])
	}

	func disableAll() {
		disable(actions: [.copy, .availableOffline, .share, .delete])
	}

	func disable(actions: [ActionsToolBarAction]) {
		_enable(actions: actions, enabled: false)
	}

	func enable(actions: [ActionsToolBarAction]) {
		_enable(actions: actions, enabled: true)
	}

	private func _enable(actions: [ActionsToolBarAction], enabled: Bool) {
		for action in actions {
			_button(for: action)?.isEnabled = enabled
		}
	}

	private func _button(for action: ActionsToolBarAction) -> UIBarButtonItem? {
		switch action {
		case .copy:
			return copyButton
		case .availableOffline:
			return availableOfflineButton
		case .share:
			return shareButton
		case .delete:
			return deleteButton
		}
	}

	// MARK: - Hidding & Showing

	func show() {
		OnMainThread {
			self.alpha = 0
			self.isHidden = false
			UIView.animate(withDuration: 0.3, animations: {
				self.alpha = 1
			})
		}
	}

	func hide() {
		OnMainThread {
			UIView.animate(withDuration: 0.3, animations: {
				self.alpha = 0
			}, completion: { (_) in
				self.isHidden = true
			})
		}
	}
}
