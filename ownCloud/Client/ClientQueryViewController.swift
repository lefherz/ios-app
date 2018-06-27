//
//  ClientQueryViewController.swift
//  ownCloud
//
//  Created by Felix Schwarz on 05.04.18.
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
import ownCloudSDK

class ClientQueryViewController: UITableViewController, Themeable {
	var core : OCCore?
	var query : OCQuery?

	var items : [OCItem]?

	var queryProgressSummary : ProgressSummary? {
		willSet {
			if newValue != nil {
				progressSummarizer?.pushFallbackSummary(summary: newValue!)
			}
		}

		didSet {
			if oldValue != nil {
				progressSummarizer?.popFallbackSummary(summary: oldValue!)
			}
		}
	}
	var progressSummarizer : ProgressSummarizer?
	var initialAppearance : Bool = true
	private var observerContextValue = 1
	private var observerContext : UnsafeMutableRawPointer
	var refreshController: UIRefreshControl?

	// MARK: - Init & Deinit
	public init(core inCore: OCCore, query inQuery: OCQuery) {
		observerContext = UnsafeMutableRawPointer(&observerContextValue)

		super.init(style: .plain)

		core = inCore
		query = inQuery

		progressSummarizer = ProgressSummarizer.shared(forCore: inCore)

		query?.delegate = self

		query?.addObserver(self, forKeyPath: "state", options: .initial, context: observerContext)
		core?.addObserver(self, forKeyPath: "reachabilityMonitor.available", options: .initial, context: observerContext)

		core?.start(query)

		self.navigationItem.title = (query?.queryPath as NSString?)!.lastPathComponent
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		query?.removeObserver(self, forKeyPath: "state", context: observerContext)
		core?.removeObserver(self, forKeyPath: "reachabilityMonitor.available", context: observerContext)

		core?.stop(query)
		Theme.shared.unregister(client: self)

		if messageThemeApplierToken != nil {
			Theme.shared.remove(applierForToken: messageThemeApplierToken)
			messageThemeApplierToken = nil
		}

		self.queryProgressSummary = nil
	}

	// MARK: - Actions
	@objc func refreshQuery() {
		UIImpactFeedbackGenerator().impactOccurred()
		core?.reload(query)
	}

	// swiftlint:disable block_based_kvo
	// Would love to use the block-based KVO, but it doesn't seem to work when used on the .state property of the query :-(
	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		if (object as? OCQuery) === query {
			self.updateQueryProgressSummary()
		}
	}
	// swiftlint:enable block_based_kvo

	// MARK: - View controller events
	override func viewDidLoad() {
		super.viewDidLoad()

		self.tableView.register(ClientItemCell.self, forCellReuseIdentifier: "itemCell")
		self.tableView.allowsMultipleSelectionDuringEditing = true

		// Uncomment the following line to preserve selection between presentations
		// self.clearsSelectionOnViewWillAppear = false

		// Uncomment the following line to display an Edit button in the navigation bar for this view controller.
		 self.navigationItem.rightBarButtonItem = self.editButtonItem

		searchController = UISearchController(searchResultsController: nil)
		searchController?.searchResultsUpdater = self
		searchController?.obscuresBackgroundDuringPresentation = false
		searchController?.hidesNavigationBarDuringPresentation = true
		searchController?.searchBar.placeholder = "Search this folder".localized

		navigationItem.searchController =  searchController
		navigationItem.hidesSearchBarWhenScrolling = false

		self.extendedLayoutIncludesOpaqueBars = true
		self.definesPresentationContext = true

		sortBar = SortBar(frame: CGRect(x: 0, y: 0, width: self.tableView.frame.width, height: 40), sortMethod: sortMethod)
		sortBar?.delegate = self
		sortBar?.updateSortMethod()

		tableView.tableHeaderView = sortBar

		refreshController = UIRefreshControl()
		refreshController?.addTarget(self, action: #selector(self.refreshQuery), for: .valueChanged)
		self.tableView.insertSubview(refreshController!, at: 0)
		tableView.contentOffset = CGPoint(x: 0, y: searchController!.searchBar.frame.height)

		Theme.shared.register(client: self, applyImmediately: true)

		createActionsToolBar()

	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		self.queryProgressSummary = nil
		searchController?.searchBar.text = ""
		searchController?.dismiss(animated: true, completion: nil)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		// Refresh when navigating back to us
		if initialAppearance == false {
			if query?.state == .idle {
				core?.reload(query)
			}
		}

		initialAppearance = false

		updateQueryProgressSummary()

		sortBar?.sortMethod = self.sortMethod
		query?.sortComparator = self.sortMethod.comparator()
	}

	func updateQueryProgressSummary() {
		var summary : ProgressSummary = ProgressSummary(indeterminate: true, progress: 1.0, message: nil, progressCount: 1)

		switch query?.state {
			case .stopped?:
				summary.message = "Stopped".localized

			case .started?:
				summary.message = "Started…".localized

			case .contentsFromCache?:
				if core?.reachabilityMonitor?.available == true {
					summary.message = "Contents from cache.".localized
				} else {
					summary.message = "Offline. Contents from cache.".localized
				}

			case .waitingForServerReply?:
				summary.message = "Waiting for server response…".localized

			case .targetRemoved?:
				summary.message = "This folder no longer exists.".localized

			case .idle?:
				summary.message = "Everything up-to-date.".localized
				summary.progressCount = 0

			case .none:
				summary.message = "Please wait…".localized
		}

		switch query?.state {
			case .idle?:
				DispatchQueue.main.async {
					if !self.refreshController!.isRefreshing {
						self.refreshController?.beginRefreshing()
					}
				}

			case .contentsFromCache?, .stopped?:
				DispatchQueue.main.async {
					self.tableView.refreshControl = nil
				}

			default:
			break
		}

		self.queryProgressSummary = summary
	}

	// MARK: - Theme support

	func applyThemeCollection(theme: Theme, collection: ThemeCollection, event: ThemeEvent) {
		self.tableView.applyThemeCollection(collection)
		self.searchController?.searchBar.applyThemeCollection(collection)

		if event == .update {
			self.tableView.reloadData()
		}
	}

	// MARK: - Table view data source
	override func numberOfSections(in tableView: UITableView) -> Int {
		// #warning Incomplete implementation, return the number of sections
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		// #warning Incomplete implementation, return the number of rows
		if self.items != nil {
			return self.items!.count
		}

		return 0
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "itemCell", for: indexPath) as? ClientItemCell
		let newItem = self.items![indexPath.row]

		cell?.core = self.core

		// UITableView can call this method several times for the same cell, and .dequeueReusableCell will then return the same cell again.
		// Make sure we don't request the thumbnail multiple times in that case.
		if (cell?.item?.itemVersionIdentifier != newItem.itemVersionIdentifier) || (cell?.item?.name != newItem.name) {
			cell?.item = newItem
		}

		return cell!
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if tableView.isEditing {
			updateActionsToolBar()
		} else {
			let rowItem : OCItem = self.items![indexPath.row]

			if rowItem.type == .collection {
				self.navigationController?.pushViewController(ClientQueryViewController(core: self.core!, query: OCQuery(forPath: rowItem.path)), animated: true)
			}
		}
	}

	override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
		updateActionsToolBar()
	}

	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		return UISwipeActionsConfiguration(actions: [
			UIContextualAction(style: .destructive, title: "Delete".localized, handler: { (_, _, actionPerformed) in
				let item = self.items![indexPath.row]

				var message = "Are you sure you want to delete this file from the server?".localized

				if item.type == .collection {
					message = "Are you sure you want to delete this folder from the server?".localized
				}

				self.deleteConfirmationActionSheet(title: item.name, message: message, completion: {
					let hudController = ProgressHUDViewController()
//					OnMainThread {
//						hudController.present(on: self, label: "Deleting...".localized)
//					}
					_ = self.core?.delete(item, requireMatch: true, resultHandler: { (error, _, _, _) in
//						OnMainThread {
//							hudController.dismiss()
//						}
						if error != nil {
							let errorAlert = UIAlertController(title: "Something wrong happened".localized, message: error?.localizedDescription, preferredStyle: .alert)
							errorAlert.addAction(UIAlertAction(title: "Ok".localized, style: .default))
//							OnMainThread {
//									self.present(errorAlert, animated: true)
//							}
						}
					})
				})
				actionPerformed(false)
			})
		])
	}

	// MARK: - Message
	var messageView : UIView?
	var messageContainerView : UIView?
	var messageImageView : VectorImageView?
	var messageTitleLabel : UILabel?
	var messageMessageLabel : UILabel?
	var messageThemeApplierToken : ThemeApplierToken?

	func message(show: Bool, imageName : String? = nil, title : String? = nil, message : String? = nil) {
		if !show {
			if messageView?.superview != nil {
				messageView?.removeFromSuperview()
			}
			return
		}

		if messageView == nil {
			var rootView : UIView
			var containerView : UIView
			var imageView : VectorImageView
			var titleLabel : UILabel
			var messageLabel : UILabel

			rootView = UIView()
			rootView.translatesAutoresizingMaskIntoConstraints = false

			containerView = UIView()
			containerView.translatesAutoresizingMaskIntoConstraints = false

			imageView = VectorImageView()
			imageView.translatesAutoresizingMaskIntoConstraints = false

			titleLabel = UILabel()
			titleLabel.translatesAutoresizingMaskIntoConstraints = false

			messageLabel = UILabel()
			messageLabel.translatesAutoresizingMaskIntoConstraints = false
			messageLabel.numberOfLines = 0
			messageLabel.textAlignment = .center

			containerView.addSubview(imageView)
			containerView.addSubview(titleLabel)
			containerView.addSubview(messageLabel)

			containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[imageView]-(20)-[titleLabel]-[messageLabel]|",
										   options: NSLayoutFormatOptions(rawValue: 0),
										   metrics: nil,
										   views: ["imageView" : imageView, "titleLabel" : titleLabel, "messageLabel" : messageLabel])
						   )

			imageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor).isActive = true
			imageView.widthAnchor.constraint(equalToConstant: 96).isActive = true
			imageView.heightAnchor.constraint(equalToConstant: 96).isActive = true

			titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor).isActive = true
			titleLabel.leftAnchor.constraint(greaterThanOrEqualTo: containerView.leftAnchor).isActive = true
			titleLabel.rightAnchor.constraint(lessThanOrEqualTo: containerView.rightAnchor).isActive = true

			messageLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor).isActive = true
			messageLabel.leftAnchor.constraint(greaterThanOrEqualTo: containerView.leftAnchor).isActive = true
			messageLabel.rightAnchor.constraint(lessThanOrEqualTo: containerView.rightAnchor).isActive = true

			rootView.addSubview(containerView)

			containerView.centerXAnchor.constraint(equalTo: rootView.centerXAnchor).isActive = true
			containerView.centerYAnchor.constraint(equalTo: rootView.centerYAnchor).isActive = true

			containerView.leftAnchor.constraint(greaterThanOrEqualTo: rootView.leftAnchor, constant: 20).isActive = true
			containerView.rightAnchor.constraint(lessThanOrEqualTo: rootView.rightAnchor, constant: -20).isActive = true
			containerView.topAnchor.constraint(greaterThanOrEqualTo: rootView.topAnchor, constant: 20).isActive = true
			containerView.bottomAnchor.constraint(lessThanOrEqualTo: rootView.bottomAnchor, constant: -20).isActive = true

			messageView = rootView
			messageContainerView = containerView
			messageImageView = imageView
			messageTitleLabel = titleLabel
			messageMessageLabel = messageLabel

			messageThemeApplierToken = Theme.shared.add(applier: { [weak self] (_, collection, _) in
				self?.messageView?.backgroundColor = collection.tableBackgroundColor

				self?.messageTitleLabel?.applyThemeCollection(collection, itemStyle: .bigTitle)
				self?.messageMessageLabel?.applyThemeCollection(collection, itemStyle: .bigMessage)
			})
		}

		if messageView?.superview == nil {
			if let rootView = self.messageView, let containerView = self.messageContainerView {
				containerView.alpha = 0
				containerView.transform = CGAffineTransform(translationX: 0, y: 15)

				rootView.alpha = 0

				self.view.addSubview(rootView)

				rootView.leftAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leftAnchor).isActive = true
				rootView.rightAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.rightAnchor).isActive = true
				rootView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor).isActive = true
				rootView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor).isActive = true

				UIView.animate(withDuration: 0.1, delay: 0.0, options: .curveEaseOut, animations: {
					rootView.alpha = 1
				}, completion: { (_) in
					UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseOut, animations: {
						containerView.alpha = 1
						containerView.transform = CGAffineTransform.identity
					})
				})
			}
		}

		if imageName != nil {
			messageImageView?.vectorImage = Theme.shared.tvgImage(for: imageName!)
		}
		if title != nil {
			messageTitleLabel?.text = title!
		}
		if message != nil {
			messageMessageLabel?.text = message!
		}
	}

	// MARK: - Sorting
	private var sortBar: SortBar?
	private var sortMethod: SortMethod {

		set {
			UserDefaults.standard.setValue(newValue.rawValue, forKey: "sort-method")
		}

		get {
			let sort = SortMethod(rawValue: UserDefaults.standard.integer(forKey: "sort-method")) ?? SortMethod.alphabeticallyDescendant
			return sort
		}
	}

	// MARK: - Search
	var searchController: UISearchController?

	// MARK: - Edit
	private var actionsToolBar: ActionsToolBar?

	private func createActionsToolBar() {
		actionsToolBar = ActionsToolBar(frame: .zero)
		actionsToolBar?.translatesAutoresizingMaskIntoConstraints = false

		self.tabBarController?.tabBar.addSubview(actionsToolBar!)

		actionsToolBar?.bottomAnchor.constraint(equalTo: self.tabBarController!.tabBar.bottomAnchor).isActive = true
		actionsToolBar?.rightAnchor.constraint(equalTo: self.tabBarController!.tabBar.rightAnchor).isActive = true
		actionsToolBar?.leftAnchor.constraint(equalTo: self.tabBarController!.tabBar.leftAnchor).isActive = true
		actionsToolBar?.topAnchor.constraint(equalTo: self.tabBarController!.tabBar.topAnchor).isActive = true

		actionsToolBar?.isHidden = true
		actionsToolBar?.disableAll()

		actionsToolBar?.actionsDelegate = self

		editButtonItem.action = #selector(editButtonItemAction)

	}

	@objc private func editButtonItemAction() {
		if tableView.isEditing {
			tableView.setEditing(false, animated: true)
			actionsToolBar?.disableAll()
			actionsToolBar?.hide()
			editButtonItem.title = "Edit".localized
		} else {
			tableView.setEditing(true, animated: true)
			actionsToolBar?.show()
			editButtonItem.title = "Cancel".localized
		}
	}

	private func updateActionsToolBar() {
		if let selectedRows = tableView.indexPathsForSelectedRows {
			if selectedRows.count > 0 {
				actionsToolBar?.enableAll()
			} else {
				actionsToolBar?.disableAll()
			}
		} else {
			actionsToolBar?.disableAll()
		}
	}

	private func deleteConfirmationActionSheet(title: String?, message: String?, completion: @escaping () -> Void) {
		let confirmationController = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
		let deleteAction = UIAlertAction(title: "Delete".localized, style: .destructive) { (_) in
			completion()
		}

		let cancelAction = UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil)

		confirmationController.addAction(deleteAction)
		confirmationController.addAction(cancelAction)

		if let popoverController = confirmationController.popoverPresentationController {
			popoverController.sourceView = self.view
			popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
			popoverController.permittedArrowDirections = []
		}
		self.present(confirmationController, animated: true)
	}
}

// MARK: - Query Delegate
extension ClientQueryViewController : OCQueryDelegate {

	func query(_ query: OCQuery!, failedWithError error: Error!) {

	}

	func queryHasChangesAvailable(_ query: OCQuery!) {
		query.requestChangeSet(withFlags: OCQueryChangeSetRequestFlag(rawValue: 0)) { (_, changeSet) in
			DispatchQueue.main.async {

				switch query.state {
				case .idle, .targetRemoved, .contentsFromCache, .stopped:
					if self.refreshController!.isRefreshing {
						self.refreshController?.endRefreshing()
					}
				default: break
				}

				self.items = changeSet?.queryResult

				switch query.state {
				case .contentsFromCache, .idle:
					if self.items?.count == 0 {
						if self.searchController?.searchBar.text != "" {
							self.message(show: true, imageName: "icon-search", title: "No matches".localized, message: "There is no results for this search".localized)
						} else {
							self.message(show: true, imageName: "folder", title: "Empty folder".localized, message: "This folder contains no files or folders.".localized)
						}
					} else {
						self.message(show: false)
					}

					self.tableView.reloadData()

				case .targetRemoved:
					self.message(show: true, imageName: "folder", title: "Folder removed".localized, message: "This folder no longer exists on the server.".localized)
					self.tableView.reloadData()

				default:
					self.message(show: false)
				}
			}
		}
	}
}

// MARK: - SortBar Delegate
extension ClientQueryViewController : SortBarDelegate {

	func sortBar(_ sortBar: SortBar, didUpdateSortMethod: SortMethod) {
		sortMethod = didUpdateSortMethod
		query?.sortComparator = sortMethod.comparator()

	}
}

// MARK: - UISearchResultsUpdating Delegate
extension ClientQueryViewController: UISearchResultsUpdating {
	func updateSearchResults(for searchController: UISearchController) {
		let searchText = searchController.searchBar.text!

		let filterHandler: OCQueryFilterHandler = { (_, _, item) -> Bool in
			if let item = item {
				if item.name.localizedCaseInsensitiveContains(searchText) {return true}

			}
			return false
		}

		if searchText == "" {
			if let filter = query?.filter(withIdentifier: "text-search") {
				query?.removeFilter(filter)
			}
		} else {
			if let filter = query?.filter(withIdentifier: "text-search") {
				query?.updateFilter(filter, applyChanges: { filterToChange in
					(filterToChange as? OCQueryFilter)?.filterHandler = filterHandler
				})
			} else {
				query?.addFilter(OCQueryFilter.init(handler: filterHandler), withIdentifier: "text-search")
			}
		}
	}

	func sortBar(_ sortBar: SortBar, presentViewController: UIViewController, animated: Bool, completionHandler: (() -> Void)?) {

		self.present(presentViewController, animated: animated, completion: completionHandler)
	}
}

// MARK: - ActionsToolBar Delegate
extension ClientQueryViewController : ActionsToolBarDelegate {

	func actionsToolBar(_ toolbar: ActionsToolBar, copyButtonPressed: UIBarButtonItem?) {
		print("Copy items pressed")
	}

	func actionsToolBar(_ toolbar: ActionsToolBar, shareButtonPressed: UIBarButtonItem?) {
		print("Share items pressed")
	}

	func actionsToolBar(_ toolbar: ActionsToolBar, availableOfflineButtonPressed: UIBarButtonItem?) {
		print("AvailableOffline items pressed")
	}

	func actionsToolBar(_ toolbar: ActionsToolBar, deleteButtonPressed: UIBarButtonItem?) {
		if let selectedIndexPaths = self.tableView.indexPathsForSelectedRows {
			self.deleteConfirmationActionSheet(title: "Multiple delete".localized, message: "Are you sure you want to delete the selected items from the server?".localized) {

				for indexPath in selectedIndexPaths {
					_ = self.core?.delete(self.items?[indexPath.row], requireMatch: true, resultHandler: { (error, _, _, _) in
						if error != nil {
							print("LOG ---> Error deleting some file \(error!)")
						}
					})
				}
			}
		}
	}
}
