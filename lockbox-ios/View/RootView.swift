/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
 // swiftlint:disable line_length

import UIKit

class RootView: UIViewController, RootViewProtocol {
    internal var presenter: RootPresenter?
    private var viewFactory: ViewFactory

    private var currentViewController: UINavigationController? {
        didSet {
            if let currentViewController = self.currentViewController {
                self.addChild(currentViewController)
                currentViewController.view.frame = self.view.bounds
                self.view.addSubview(currentViewController.view)
                currentViewController.didMove(toParent: self)

                if oldValue != nil {
                    self.view.sendSubviewToBack(currentViewController.view)
                }
            }

            guard let oldViewController = oldValue else {
                return
            }
            oldViewController.willMove(toParent: nil)
            oldViewController.view.removeFromSuperview()
            oldViewController.removeFromParent()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return self.currentViewController?.topViewController?.preferredStatusBarStyle ?? .lightContent
    }

    init(viewFactory: ViewFactory = ViewFactory.shared) {
        self.viewFactory = viewFactory
        super.init(nibName: nil, bundle: nil)
        if !isRunningTest {
            self.presenter = RootPresenter(view: self)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.presenter?.onViewReady()
    }

    func topViewIs<T: UIViewController>(_ type: T.Type) -> Bool {
        return self.currentViewController?.topViewController is T
    }

    func modalViewIs<T: UIViewController>(_ type: T.Type) -> Bool {
        return (self.currentViewController?.presentedViewController as? UINavigationController)?.topViewController is T
    }

    func mainStackIs<T: UINavigationController>(_ type: T.Type) -> Bool {
        return self.currentViewController is T
    }

    func modalStackIs<T: UINavigationController>(_ type: T.Type) -> Bool {
        return self.currentViewController?.presentedViewController is T
    }

    var modalStackPresented: Bool {
        return self.currentViewController?.presentedViewController is UINavigationController
    }

    func startMainStack<T: UINavigationController>(_ type: T.Type) {
        if let vc = self.viewFactory.make(type) as? UINavigationController {
            self.currentViewController = vc
        }
    }

    func startModalStack<T: UINavigationController>(_ navigationController: T) {
        self.currentViewController?.present(navigationController, animated: true)
    }

    func dismissModals() {
        self.currentViewController?.presentedViewController?.dismiss(animated: !isRunningTest, completion: nil)
    }

    func pushLoginView(view: LoginRouteAction) {
        switch view {
        case .welcome:
            self.currentViewController?.popToRootViewController(animated: !isRunningTest)
        case .fxa:
            self.currentViewController?.pushViewController(self.viewFactory.make(FxAView.self), animated: !isRunningTest)
        case .onboardingConfirmation:
            let onboardingConfirmationView = self.viewFactory.make(storyboardName: "OnboardingConfirmation", identifier: "onboardingconfirmation")
            self.currentViewController?.pushViewController(onboardingConfirmationView, animated: !isRunningTest)
        case .autofillOnboarding:
            let autofillOnboardingView = self.viewFactory.make(storyboardName: "AutofillOnboarding", identifier: "autofillonboarding")
            self.currentViewController?.pushViewController(autofillOnboardingView, animated: !isRunningTest)
        case .autofillInstructions:
            let autofillInstructionsView = self.viewFactory.make(storyboardName: "SetupAutofill", identifier: "autofillinstructions")
            self.currentViewController?.pushViewController(autofillInstructionsView, animated: !isRunningTest)
        }
    }

    func pushMainView(view: MainRouteAction) {
        switch view {
        case .list:
            self.currentViewController?.popToRootViewController(animated: !isRunningTest)
        case .detail(let id):

            if let itemDetailView = self.viewFactory.make(storyboardName: "ItemDetail", identifier: "itemdetailview") as? ItemDetailView {
                itemDetailView.itemId = id
                self.currentViewController?.pushViewController(itemDetailView, animated: !isRunningTest)
            }
        }
    }

    func pushSettingView(view: SettingRouteAction) {
        switch view {
        case .list:
            self.currentViewController?.popToRootViewController(animated: !isRunningTest)
        case .account:
            let accountSettingView = self.viewFactory.make(storyboardName: "AccountSetting", identifier: "accountsetting")
            self.currentViewController?.pushViewController(accountSettingView, animated: !isRunningTest)
        case .autoLock:
            self.currentViewController?.pushViewController(self.viewFactory.make(AutoLockSettingView.self), animated: !isRunningTest)
        case .preferredBrowser:
            self.currentViewController?.pushViewController(self.viewFactory.make(PreferredBrowserSettingView.self), animated: !isRunningTest)
        case .autofillInstructions:
            let autofillSettingView = self.viewFactory.make(storyboardName: "SetupAutofill", identifier: "autofillinstructions")
            self.currentViewController?.pushViewController(autofillSettingView, animated: !isRunningTest)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
    }
}
