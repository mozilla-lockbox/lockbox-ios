/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import RxCocoa
import RxSwift

protocol AccountSettingViewProtocol: class, AlertControllerView {
    func bind(avatarImage: Driver<Data>)
    func bind(displayName: Driver<String>)
}

class AccountSettingPresenter {
    weak var view: AccountSettingViewProtocol?
    let dispatcher: Dispatcher
    let accountStore: AccountStore

    lazy private var unlinkAccountObserver: AnyObserver<Void> = {
        return Binder(self) { target, _ in
            target.dispatcher.dispatch(action: CredentialProviderAction.clear)
            target.dispatcher.dispatch(action: DataStoreAction.reset)
            target.dispatcher.dispatch(action: AccountAction.clear)
        }.asObserver()
    }()

    lazy private(set) var onSettingsTap: AnyObserver<Void> = {
        return Binder(self) { target, _ in
            target.dispatcher.dispatch(action: SettingRouteAction.list)
        }.asObserver()
    }()

    lazy private(set) var unLinkAccountTapped: AnyObserver<Void> = {
        return Binder(self) { target, _ in
            target.view?.displayAlertController(buttons: [
                AlertActionButtonConfiguration(title: Constant.string.cancel,
                                               tapObserver: nil,
                                               style: .cancel),
                AlertActionButtonConfiguration(title: Constant.string.unlink,
                        tapObserver: target.unlinkAccountObserver,
                        style: .destructive)],
                    title: Constant.string.confirmDialogTitle,
                    message: Constant.string.confirmDialogMessage,
                    style: .alert)
        }.asObserver()
    }()

    init(view: AccountSettingViewProtocol,
         dispatcher: Dispatcher = .shared,
         accountStore: AccountStore = AccountStore.shared
    ) {
        self.view = view
        self.dispatcher = dispatcher
        self.accountStore = accountStore
    }

    func onViewReady() {
        let profileObservable = self.accountStore.profile
                .filterNil()

        let displayNameDriver = profileObservable
                .map { $0.displayName ?? $0.email }
                .asDriver(onErrorJustReturn: "")

        self.view?.bind(displayName: displayNameDriver)

        let avatarImageDriver = profileObservable
                .flatMap { info -> Observable<Data?> in
                    guard let avatarURL = URL(string: info.avatar) else {
                        return Observable.just(nil)
                    }

                    return Data.loadImageData(avatarURL)
                }
                .filterByType(class: Data?.self)
                .asDriver(onErrorJustReturn: nil)
                .filterNil()

        self.view?.bind(avatarImage: avatarImageDriver)
    }
}
