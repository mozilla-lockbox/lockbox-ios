/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import UIKit
import RxSwift
import RxCocoa
import RxDataSources

protocol SettingsProtocol {
    func bind(items: Driver<[SettingSectionModel]>)
}

typealias SettingSectionModel = AnimatableSectionModel<Int, SettingCellConfiguration>

class SettingsView: UITableViewController {
    var presenter: SettingsPresenter?
    private var disposeBag = DisposeBag()
    private var dataSource: RxTableViewSectionedReloadDataSource<SettingSectionModel>?

    init() {
        super.init(nibName: nil, bundle: nil)
        self.presenter = SettingsPresenter(view: self)
        view.backgroundColor = Constant.color.settingsBackground
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    private func setupNavbar() {
        navigationItem.title = Constant.string.settingsTitle
        navigationController?.navigationBar.tintColor = UIColor.white
        navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedStringKey.foregroundColor: UIColor.white,
            NSAttributedStringKey.font: UIFont.systemFont(ofSize: 18, weight: .semibold)
        ]

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: Constant.string.done,
                                                            style: .done,
                                                            target: nil,
                                                            action: nil)
        navigationItem.rightBarButtonItem?.tintColor = UIColor.white

        if let presenter = presenter {
            navigationItem.rightBarButtonItem?.rx.tap
                .bind(to: presenter.onDone)
                .disposed(by: self.disposeBag)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setupNavbar()
        self.setupFooter()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupDataSource()
        self.setupDelegate()
        self.presenter?.onViewReady()
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let cell = UITableViewCell()
        cell.textLabel?.textColor = Constant.color.settingsHeader
        cell.textLabel?.font = UIFont.systemFont(ofSize: 13.0, weight: UIFont.Weight.regular)
        cell.textLabel?.text = section == 0 ?
            Constant.string.settingsHelpSectionHeader : Constant.string.settingsConfigurationSectionHeader
        return cell
    }

    @objc private func switchChanged(sender: UISwitch) {
        let rowChanged = sender.tag
        presenter?.switchChanged(row: rowChanged, isOn: sender.isOn)
    }
}

extension SettingsView {
    private func setupFooter() {
        let footer = UIView()
        tableView.tableFooterView = footer
    }

    private func setupDataSource() {
        self.dataSource = RxTableViewSectionedReloadDataSource(
            configureCell: { _, _, _, cellConfiguration in
                let cell = UITableViewCell()
                cell.textLabel?.text = cellConfiguration.text

                if cellConfiguration.routeAction != nil {
                    cell.accessoryType = .disclosureIndicator
                } else if let switchSetting = cellConfiguration as? SwitchSettingCellConfiguration {
                    let switchItem = UISwitch()
                    switchItem.onTintColor = Constant.color.lockBoxBlue
                    switchItem.addTarget(self, action: #selector(self.switchChanged), for: .valueChanged)
                    switchItem.isOn = switchSetting.isOn
                    cell.accessoryView = switchItem
                    cell.selectionStyle = UITableViewCellSelectionStyle.none
                }
                return cell
        })
    }

    private func setupDelegate() {
        guard let presenter = presenter else { return }
        self.tableView.rx.itemSelected
            .map { (indexPath) -> SettingCellConfiguration? in
                self.tableView.deselectRow(at: indexPath, animated: true)
                return self.dataSource?[indexPath]
            }.bind(to: presenter.itemSelectedObserver)
            .disposed(by: disposeBag)
    }
}

extension SettingsView: SettingsProtocol {
    func bind(items: Driver<[SettingSectionModel]>) {
        guard let dataSource = self.dataSource else {
            fatalError("datasource not set!")
        }

        items
            .drive(self.tableView.rx.items(dataSource: dataSource))
            .disposed(by: self.disposeBag)
    }
}

class SettingCellConfiguration {
    var text: String
    var routeAction: SettingRouteAction?

    init(text: String, routeAction: SettingRouteAction?) {
        self.text = text
        self.routeAction = routeAction
    }
}

extension SettingCellConfiguration: IdentifiableType {
    var identity: String {
        return self.text
    }
}

extension SettingCellConfiguration: Equatable {
    static func ==(lhs: SettingCellConfiguration, rhs: SettingCellConfiguration) -> Bool {
        return lhs.text == rhs.text && lhs.routeAction == rhs.routeAction
    }
}

class SwitchSettingCellConfiguration: SettingCellConfiguration {
    var isOn: Bool = false

    init(text: String, routeAction: SettingRouteAction?, isOn: Bool = false) {
        super.init(text: text, routeAction: routeAction)
        self.isOn = isOn
    }
}

class CheckmarkSettingCellConfiguration: SettingCellConfiguration {
    var isChecked: Bool = false
    var valueWhenChecked: Any?

    init(text: String, isChecked: Bool = false, valueWhenChecked: Any?) {
        super.init(text: text, routeAction: nil)
        self.isChecked = isChecked
        self.valueWhenChecked = valueWhenChecked
    }
}
