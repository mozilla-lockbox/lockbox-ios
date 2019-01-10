/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import RxSwift
import RxCocoa
import UIKit
import FxAClient

protocol RootViewProtocol: class {
    func topViewIs<T: UIViewController>(_ type: T.Type) -> Bool
    func modalViewIs<T: UIViewController>(_ type: T.Type) -> Bool
    func sidebarViewIs<T: UIViewController>(_ type: T.Type) -> Bool
    func detailViewIs<T: UIViewController>(_ type: T.Type) -> Bool
    func mainStackIs<T: UIViewController>(_ type: T.Type) -> Bool
    func modalStackIs<T: UINavigationController>(_ type: T.Type) -> Bool
    var modalStackPresented: Bool { get }

    func startMainStack<T: UIViewController>(_ viewController: T)
    func startModalStack<T: UINavigationController>(_ navigationController: T)
    func dismissModals()

    func push(view: UIViewController)
    func pushSidebar(view: UIViewController)
    func pushDetail(view: UIViewController)
    func popView()
    func popToRoot()
}

struct OAuthProfile {
    let oauthInfo: OAuthInfo?
    let profile: Profile?
}

extension OAuthProfile: Equatable {
    static func ==(lh: OAuthProfile, rh: OAuthProfile) -> Bool {
        return lh.profile == rh.profile &&
                lh.oauthInfo == rh.oauthInfo
    }
}

class RootPresenter {
    private weak var view: RootViewProtocol?
    private let disposeBag = DisposeBag()

    fileprivate let dispatcher: Dispatcher
    fileprivate let routeStore: RouteStore
    fileprivate let dataStore: DataStore
    fileprivate let telemetryStore: TelemetryStore
    fileprivate let accountStore: AccountStore
    fileprivate let userDefaultStore: UserDefaultStore
    fileprivate let lifecycleStore: LifecycleStore
    fileprivate let telemetryActionHandler: TelemetryActionHandler
    fileprivate let biometryManager: BiometryManager
    fileprivate let sentryManager: Sentry
    fileprivate let adjustManager: AdjustManager
    fileprivate let tabletHelper: TabletHelper
    fileprivate let viewFactory: ViewFactory

    var fxa: FirefoxAccount?

    init(view: RootViewProtocol,
         dispatcher: Dispatcher = .shared,
         routeStore: RouteStore = RouteStore.shared,
         dataStore: DataStore = DataStore.shared,
         telemetryStore: TelemetryStore = TelemetryStore.shared,
         accountStore: AccountStore = AccountStore.shared,
         userDefaultStore: UserDefaultStore = .shared,
         lifecycleStore: LifecycleStore = .shared,
         telemetryActionHandler: TelemetryActionHandler = TelemetryActionHandler(accountStore: AccountStore.shared),
         biometryManager: BiometryManager = BiometryManager(),
         sentryManager: Sentry = Sentry.shared,
         adjustManager: AdjustManager = AdjustManager.shared,
         tabletHelper: TabletHelper = TabletHelper.shared,
         viewFactory: ViewFactory = ViewFactory.shared
    ) {
        self.view = view
        self.dispatcher = dispatcher
        self.routeStore = routeStore
        self.dataStore = dataStore
        self.telemetryStore = telemetryStore
        self.accountStore = accountStore
        self.userDefaultStore = userDefaultStore
        self.lifecycleStore = lifecycleStore
        self.telemetryActionHandler = telemetryActionHandler
        self.biometryManager = biometryManager
        self.sentryManager = sentryManager
        self.adjustManager = adjustManager
        self.tabletHelper = tabletHelper
        self.viewFactory = viewFactory

        // todo: update tests with populated oauth and profile info
        Observable.combineLatest(self.accountStore.oauthInfo, self.accountStore.profile)
                .map { OAuthProfile(oauthInfo: $0.0, profile: $0.1) }
                .distinctUntilChanged()
                .bind { latest in
                    if let oauthInfo = latest.oauthInfo,
                        let profile = latest.profile {
                        self.dispatcher.dispatch(action: DataStoreAction.updateCredentials(oauthInfo: oauthInfo, fxaProfile: profile))
                    } else if latest.oauthInfo == nil && latest.profile == nil {
                        self.dispatcher.dispatch(action: LoginRouteAction.welcome)
                        self.dispatcher.dispatch(action: DataStoreAction.reset)
                        self.dispatcher.dispatch(action: CredentialProviderAction.clear)
                        self.dispatcher.dispatch(action: AccountAction.clear)
                    }
                }
                .disposed(by: self.disposeBag)

        self.dataStore.storageState
            .subscribe(onNext: { storageState in
                switch storageState {
                case .Unprepared, .Locked:
                    self.dispatcher.dispatch(action: LoginRouteAction.welcome)
                case .Unlocked:
                    self.dispatcher.dispatch(action: MainRouteAction.list)
                    self.dispatcher.dispatch(action: CredentialProviderAction.refresh)
                default:
                    break
                }
            })
            .disposed(by: self.disposeBag)

        Observable.combineLatest(self.dataStore.syncState, self.dataStore.storageState)
            .filter { $0.1 == LoginStoreState.Unprepared }
            .map { $0.0 }
            .distinctUntilChanged()
            .subscribe(onNext: { syncState in
                if syncState == .NotSyncable {
                    self.dispatcher.dispatch(action: LoginRouteAction.welcome)
                }
            })
            .disposed(by: self.disposeBag)

        self.dispatcher.dispatch(action: OnboardingStatusAction(onboardingInProgress: false))
        self.startTelemetry()
        self.startAdjust()
        self.startSentry()
    }

    func onViewReady() {
        self.routeStore.onRoute
                .filterByType(class: LoginRouteAction.self)
                .asDriver(onErrorJustReturn: .welcome)
                .drive(showLogin)
                .disposed(by: disposeBag)

        Observable.combineLatest(self.routeStore.onRoute, self.routeStore.onboarding)
                .filter { !$0.1 }
                .map { $0.0 }
                .filterByType(class: MainRouteAction.self)
                .asDriver(onErrorJustReturn: .list)
                .drive(showList)
                .disposed(by: disposeBag)

        Observable.combineLatest(self.routeStore.onRoute, self.routeStore.onboarding)
                .filter { !$0.1 }
                .map { $0.0 }
                .filterByType(class: SettingRouteAction.self)
                .asDriver(onErrorJustReturn: .list)
                .drive(self.showSetting)
                .disposed(by: self.disposeBag)

        self.routeStore.onRoute
                .filterByType(class: ExternalWebsiteRouteAction.self)
                .asDriver(onErrorJustReturn: ExternalWebsiteRouteAction(
                        urlString: "",
                        title: "Error",
                        returnRoute: MainRouteAction.list))
                .drive(self.showExternalWebsite)
                .disposed(by: self.disposeBag)
    }

    lazy private var showLogin: AnyObserver<LoginRouteAction> = { [unowned self] in
        return Binder(self) { target, loginAction in
            guard let view = target.view else {
                return
            }

            if view.modalStackPresented {
                view.dismissModals()
            }

            if !view.mainStackIs(LoginNavigationController.self) {
                view.startMainStack(LoginNavigationController())
            }

            switch loginAction {
            case .welcome:
                if !view.topViewIs(WelcomeView.self) {
                    view.popToRoot()
                }
            case .fxa:
                if !view.topViewIs(FxAView.self) {
                    view.push(view: self.viewFactory.make(FxAView.self))
                }
            case .onboardingConfirmation:
                if !view.topViewIs(OnboardingConfirmationView.self) {
                    view.push(view: self.viewFactory.make(storyboardName: "OnboardingConfirmation", identifier: "onboardingconfirmation"))
                }
            case .autofillOnboarding:
                if !view.topViewIs(AutofillOnboardingView.self) {
                    view.push(view: self.viewFactory.make(storyboardName: "AutofillOnboarding", identifier: "autofillonboarding"))
                }
            case .autofillInstructions:
                if !view.topViewIs(AutofillInstructionsView.self) {
                    view.push(view: self.viewFactory.make(storyboardName: "SetupAutofill", identifier: "autofillinstructions"))
                }
            }
        }.asObserver()
    }()

    lazy private var showList: AnyObserver<MainRouteAction> = { [unowned self] in
        return Binder(self) { target, mainAction in
            guard let view = target.view else {
                return
            }

            if view.modalStackPresented {
                view.dismissModals()
            }

            if self.shouldDisplaySidebar {
                if !view.mainStackIs(SplitView.self) {
                    view.startMainStack(SplitView())
                }
            } else {
                if !view.mainStackIs(MainNavigationController.self) {
                    view.startMainStack(MainNavigationController(storyboardName: "ItemList", identifier: "itemlist"))
                }
            }

            switch mainAction {
            case .list:
                if self.shouldDisplaySidebar {
                    if !view.sidebarViewIs(ItemListView.self) {
                        view.pushSidebar(view: self.viewFactory.make(storyboardName: "ItemList", identifier: "itemlist"))
                    }
                } else {
                    if !view.topViewIs(ItemListView.self) {
                        view.popToRoot()
                    }
                }
            case .detail(let id):
                if !view.topViewIs(ItemDetailView.self) {
                    let detailView: ItemDetailView = self.viewFactory.make(storyboardName: "ItemDetail", identifier: "itemdetailview")
                    detailView.itemId = id

                    if self.shouldDisplaySidebar {
                        view.pushDetail(view: detailView)
                    } else {
                        view.push(view: detailView)
                    }
                }
            }
        }.asObserver()
    }()

    lazy private var showSetting: AnyObserver<SettingRouteAction> = { [unowned self] in
        return Binder(self) { target, settingAction in
            guard let view = target.view else {
                return
            }

            if view.modalStackPresented {
                view.dismissModals()
            }

            if !view.mainStackIs(SettingNavigationController.self) {
                view.startMainStack(SettingNavigationController())
            }

            switch settingAction {
            case .list:
                if !view.topViewIs(SettingListView.self) {
                    view.popToRoot()
                }
            case .account:
                if !view.topViewIs(AccountSettingView.self) {
                    view.push(view: self.viewFactory.make(storyboardName: "AccountSetting", identifier: "accountsetting"))
                }
            case .autoLock:
                if !view.topViewIs(AutoLockSettingView.self) {
                    view.push(view: self.viewFactory.make(AutoLockSettingView.self))
                }
            case .preferredBrowser:
                if !view.topViewIs(PreferredBrowserSettingView.self) {
                    view.push(view: self.viewFactory.make(PreferredBrowserSettingView.self))
                }
            case .autofillInstructions:
                if !view.modalStackIs(AutofillInstructionsNavigationController.self) {
                    view.startModalStack(AutofillInstructionsNavigationController())
                }
            }
        }.asObserver()
    }()

    lazy private var showExternalWebsite: AnyObserver<ExternalWebsiteRouteAction> = { [unowned self] in
        return Binder(self) { target, externalSiteAction in
            guard let view = target.view else {
                return
            }

            if !view.modalStackIs(ExternalWebsiteNavigationController.self) {
                view.startModalStack(
                        ExternalWebsiteNavigationController(
                                urlString: externalSiteAction.urlString,
                                title: externalSiteAction.title,
                                returnRoute: externalSiteAction.returnRoute
                        )
                )
            }
        }.asObserver()
    }()

    private var shouldDisplaySidebar: Bool {
        return self.tabletHelper.shouldDisplaySidebar
    }
}

extension RootPresenter {
    fileprivate func startTelemetry() {
        Observable.combineLatest(self.telemetryStore.telemetryFilter, self.userDefaultStore.recordUsageData)
                .filter { $0.1 }
                .map { $0.0 }
                .bind(to: self.telemetryActionHandler.telemetryActionListener)
                .disposed(by: self.disposeBag)
    }

    fileprivate func startAdjust() {
        self.userDefaultStore.recordUsageData.subscribe(onNext: { enabled in
            self.adjustManager.setEnabled(enabled)
        }).disposed(by: self.disposeBag)
    }

    fileprivate func startSentry() {
        self.userDefaultStore.recordUsageData
            .take(1)
            .subscribe(onNext: { enabled in
                self.sentryManager.setup(sendUsageData: enabled)
        }).disposed(by: self.disposeBag)
    }
}
