/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import RxSwift
import AuthenticationServices

protocol CredentialProviderViewProtocol: class {
    var extensionContext: ASCredentialProviderExtensionContext { get }
}

class CredentialProviderPresenter {
    weak var view: CredentialProviderViewProtocol?

    private let dispatcher: Dispatcher
    private let accountStore: AccountStore
    private let dataStore: DataStore
    private let disposeBag = DisposeBag()

    init(view: CredentialProviderViewProtocol,
         dispatcher: Dispatcher = .shared,
         accountStore: AccountStore = .shared,
         dataStore: DataStore = .shared) {
        self.view = view
        self.dispatcher = dispatcher
        self.accountStore = accountStore
        self.dataStore = dataStore

        Observable.combineLatest(self.accountStore.oauthInfo, self.accountStore.profile)
            .bind { (oauthInfo, profile) in
                if let oauthInfo = oauthInfo,
                    let profile = profile {
                    self.dispatcher.dispatch(action: DataStoreAction.updateCredentials(oauthInfo: oauthInfo, fxaProfile: profile))
                }
            }
            .disposed(by: self.disposeBag)
    }

    func extensionConfigurationRequested() {
        self.dispatcher.dispatch(action: LifecycleAction.foreground)
        self.dispatcher.dispatch(action: DataStoreAction.unlock)
        
        self.dataStore.storageState
            .bind { (state) in
                print(state)
            }
            .disposed(by: self.disposeBag)
        
        self.dataStore.list
            .bind { (logins) in
                print(logins)
//                self.view?.extensionContext.completeExtensionConfigurationRequest()
            }
            .disposed(by: self.disposeBag)
        
    }
}
