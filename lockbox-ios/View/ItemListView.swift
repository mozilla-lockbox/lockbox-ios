/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import RxSwift
import RxCocoa
import RxDataSources

typealias ItemSectionModel = AnimatableSectionModel<Int, ItemListCellConfiguration>

enum ItemListCellConfiguration {
    case Search
    case Item(title: String, username: String, id: String?)
}

extension ItemListCellConfiguration: IdentifiableType {
    var identity: String {
        switch self {
        case .Search:
            return "search"
        case .Item(let title, _, _):
            return title
        }
    }
}

extension ItemListCellConfiguration: Equatable {
    static func ==(lhs: ItemListCellConfiguration, rhs: ItemListCellConfiguration) -> Bool {
        switch (lhs, rhs) {
        case (.Search, .Search): return true
        case (.Item(let lhTitle, let lhUsername, _), .Item(let rhTitle, let rhUsername, _)):
            return lhTitle == rhTitle && lhUsername == rhUsername
        default:
            return false
        }
    }
}

class ItemListView: UIViewController {
    var presenter: ItemListPresenter?
    @IBOutlet weak var tableView: UITableView!
    private var disposeBag = DisposeBag()
    private var dataSource: RxTableViewSectionedAnimatedDataSource<ItemSectionModel>?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.presenter = ItemListPresenter(view: self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.styleTableViewBackground()
        self.styleNavigationBar()
        self.setupDataSource()
        self.setupDelegate()
        self.presenter?.onViewReady()
    }
}

extension ItemListView: ItemListViewProtocol {
    func bind(items: Driver<[ItemSectionModel]>) {
        guard let dataSource = self.dataSource else {
            fatalError("dataSource not set!")
        }

        items.drive(self.tableView.rx.items(dataSource: dataSource)).disposed(by: self.disposeBag)
    }

    func displayEmptyStateMessaging() {
        guard let emptyStateView = Bundle.main.loadNibNamed("EmptyList", owner: self)?[0] as? UIView else {
            return
        }
        self.tableView.backgroundView?.addSubview(emptyStateView)
    }

    func hideEmptyStateMessaging() {
        self.tableView.backgroundView?.subviews.forEach({ $0.removeFromSuperview() })
    }
}

extension ItemListView {
    fileprivate func setupDataSource() {
        self.dataSource = RxTableViewSectionedAnimatedDataSource<ItemSectionModel>(
                configureCell: { dataSource, tableView, path, _ in
                    let cellConfiguration = dataSource[path]

                    var retCell: UITableViewCell
                    switch cellConfiguration {
                    case .Search:
                        guard let cell = tableView.dequeueReusableCell(withIdentifier: "filtercell") as? FilterCell,
                                let presenter = self.presenter else {
                            fatalError("couldn't find the right cell or presenter!")
                        }

                        cell.filterTextField.rx.text
                                .orEmpty
                                .asObservable()
                                .bind(to: presenter.filterTextObserver)
                                .disposed(by: cell.disposeBag)

                        retCell = cell
                    case .Item(let title, let username, _):
                        guard let cell = tableView.dequeueReusableCell(withIdentifier: "itemlistcell") as? ItemListCell else { // swiftlint:disable:this line_length
                            fatalError("couldn't find the right cell!")
                        }

                        cell.titleLabel.text = title
                        cell.detailLabel.text = username

                        retCell = cell
                    }

                    return retCell
                })

        self.dataSource?.animationConfiguration = AnimationConfiguration(
                insertAnimation: .fade,
                reloadAnimation: .automatic,
                deleteAnimation: .fade
        )
    }

    fileprivate func setupDelegate() {
        guard let presenter = self.presenter else {
            return
        }

        self.tableView.rx.itemSelected
                .map { (path: IndexPath) -> String? in
                    guard let config = self.dataSource?[path] else {
                        return nil
                    }

                    switch config {
                    case .Item(_, _, let id):
                        return id
                    default:
                        return nil
                    }
                }
                .bind(to: presenter.itemSelectedObserver)
                .disposed(by: self.disposeBag)
    }
}

// view styling
extension ItemListView {
    fileprivate func styleNavigationBar() {
        let prefButton = UIButton()
        let prefImage = UIImage(named: "preferences")?.withRenderingMode(.alwaysTemplate)
        prefButton.setImage(prefImage, for: .normal)
        prefButton.tintColor = .white

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: prefButton)
        self.navigationItem.title = Constant.string.yourLockbox

        self.navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedStringKey.foregroundColor: UIColor.white,
            NSAttributedStringKey.font: UIFont.systemFont(ofSize: 18, weight: .semibold)
        ]
    }

    fileprivate func styleTableViewBackground() {
        let backgroundView = UIView(frame: self.view.bounds)
        backgroundView.backgroundColor = Constant.color.lightGrey
        self.tableView.backgroundView = backgroundView
    }
}
