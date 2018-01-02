/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import WebKit

class ItemListView : UITableViewController, ItemListViewProtocol {
    var presenter:ItemListPresenter!
    internal(set) var webView: WebView

    private var items:[Item] = []

    required init?(coder aDecoder: NSCoder) {
        let webConfig = WKWebViewConfiguration()

        webConfig.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        webConfig.preferences.javaScriptEnabled = true

        self.webView = WebView(frame: .zero, configuration: webConfig)
        super.init(coder: aDecoder)
    }

    func displayItems(_ items: [Item]) {
        self.items = items
        self.tableView.reloadData()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(self.webView)

        self.navigationItem.title = "Your Lockbox"
        styleNavigationBar()

        self.presenter.onViewReady()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "itemlistcell") as? ItemListCell
        let item = items[indexPath.row]

        cell!.titleLabel.text = item.title
        cell!.detailLabel.text = item.entry.username
        cell!.detailLabel.text = (item.entry.username == "" || item.entry.username == nil) ? "(no username)" : item.entry.username
        cell!.kebabButton.tintColor = UIColor.kebabBlue

        return cell!
    }
    
    @objc private func preferencesTapped() {
        Router.shared.routeToSettings(window: UIApplication.shared.keyWindow!)
    }

    private func styleNavigationBar() {
        let prefButton = UIButton()
        let prefImage = UIImage(named: "preferences")?.withRenderingMode(.alwaysTemplate)
        prefButton.setImage(prefImage, for: .normal)
        prefButton.tintColor = .white
        prefButton.addTarget(self, action: #selector(ItemListView.preferencesTapped), for: .touchUpInside)

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: prefButton)
        self.navigationItem.rightBarButtonItem?.action = #selector(ItemListView.preferencesTapped)
        self.navigationItem.title = "Your Lockbox"

        self.navigationController!.navigationBar.titleTextAttributes = [
            NSAttributedStringKey.foregroundColor: UIColor.white,
            NSAttributedStringKey.font: UIFont.systemFont(ofSize: 18, weight: .semibold)
        ]

        self.navigationController!.navigationBar.addLockboxGradient()
        self.navigationController!.navigationBar.layoutIfNeeded()
    }
}
