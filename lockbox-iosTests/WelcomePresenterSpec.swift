/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Quick
import Nimble
import Foundation
import RxSwift
import RxCocoa
import RxTest
import UIKit
import CoreGraphics
import LocalAuthentication

@testable import Lockbox

class WelcomePresenterSpec: QuickSpec {
    class FakeWelcomeView: WelcomeViewProtocol {
        var fakeFxAButtonPress = PublishSubject<Void>()
        var fakeLoginButtonPress = PublishSubject<Void>()
        var fakeBiometricButtonPress = PublishSubject<Void>()
        var firstTimeMessageHiddenStub: TestableObserver<Bool>!
        var firstTimeLearnMoreHiddenStub: TestableObserver<Bool>!
        var loginButtonHiddenStub: TestableObserver<Bool>!
        var biometricButtonHiddenStub: TestableObserver<Bool>!
        var biometricLabelHiddenStub: TestableObserver<Bool>!
        var biometricImageNameStub: TestableObserver<String>!
        var biometricButtonTitleStub: TestableObserver<String?>!
        var alertControllerButtons: [AlertActionButtonConfiguration]?
        var alertControllerTitle: String?
        var alertControllerMessage: String?
        var alertControllerStyle: UIAlertControllerStyle?

        var loginButtonPressed: ControlEvent<Void> {
            return ControlEvent<Void>(events: fakeLoginButtonPress.asObservable())
        }

        var learnMorePressed: ControlEvent<Void> {
            return ControlEvent<Void>(events: fakeFxAButtonPress.asObservable())
        }

        var biometricButtonPressed: ControlEvent<Void> {
            return ControlEvent<Void>(events: fakeBiometricButtonPress.asObservable())
        }

        var firstTimeLoginMessageHidden: AnyObserver<Bool> {
            return self.firstTimeMessageHiddenStub.asObserver()
        }
        var firstTimeLearnMoreHidden: AnyObserver<Bool> {
            return self.firstTimeLearnMoreHiddenStub.asObserver()
        }

        var loginButtonHidden: AnyObserver<Bool> {
            return self.loginButtonHiddenStub.asObserver()
        }

        var biometricButtonHidden: AnyObserver<Bool> {
            return self.biometricButtonHiddenStub.asObserver()
        }

        var biometricButtonTitleHidden: AnyObserver<Bool> {
            return self.biometricLabelHiddenStub.asObserver()
        }

        var biometricButtonImageName: AnyObserver<String> {
            return self.biometricImageNameStub.asObserver()
        }

        var biometricButtonTitle: AnyObserver<String?> {
            return self.biometricButtonTitleStub.asObserver()
        }

        func displayAlertController(buttons: [AlertActionButtonConfiguration],
                                    title: String?,
                                    message: String?,
                                    style: UIAlertControllerStyle) {
            self.alertControllerButtons = buttons
            self.alertControllerTitle = title
            self.alertControllerMessage = message
            self.alertControllerStyle = style
        }
    }

    class FakeRouteActionHandler: RouteActionHandler {
        var invokeArgument: RouteAction?

        override func invoke(_ action: RouteAction) {
            self.invokeArgument = action
        }
    }

    class FakeDataStoreActionHandler: DataStoreActionHandler {
        var invokeArgument: DataStoreAction?

        override func invoke(_ action: DataStoreAction) {
            self.invokeArgument = action
        }
    }

    class FakeLinkActionHandler: LinkActionHandler {
        var invokeArgument: LinkAction?

        override func invoke(_ action: LinkAction) {
            self.invokeArgument = action
        }
    }

    class FakeUserInfoStore: UserInfoStore {
        var fakeProfileInfo = PublishSubject<ProfileInfo?>()

        override var profileInfo: Observable<ProfileInfo?> {
            return self.fakeProfileInfo.asObservable()
        }
    }

    class FakeDataStore: DataStore {
        var fakeLocked = ReplaySubject<Bool>.create(bufferSize: 1)

        override var locked: Observable<Bool> {
            return self.fakeLocked.asObservable()
        }
    }

    class FakeLifecycleStore: LifecycleStore {
        var fakeCycle = PublishSubject<LifecycleAction>()

        override var lifecycleFilter: Observable<LifecycleAction> {
            return self.fakeCycle.asObservable()
        }
    }

    class FakeBiometryManager: BiometryManager {
        var authMessage: String?
        var fakeAuthResponse = PublishSubject<Void>()
        var deviceAuthAvailableStub: Bool!
        var touchIDStub: Bool = false
        var faceIDStub: Bool = false

        override func authenticateWithMessage(_ message: String) -> Single<Void> {
            self.authMessage = message
            return fakeAuthResponse.take(1).asSingle()
        }

        override var deviceAuthenticationAvailable: Bool {
            return self.deviceAuthAvailableStub
        }

        override var usesTouchID: Bool {
            return self.touchIDStub
        }

        override var usesFaceID: Bool {
            return self.faceIDStub
        }
    }

    private var view: FakeWelcomeView!
    private var routeActionHandler: FakeRouteActionHandler!
    private var dataStoreActionHandler: FakeDataStoreActionHandler!
    private var linkActionHandler: FakeLinkActionHandler!
    private var userInfoStore: FakeUserInfoStore!
    private var dataStore: FakeDataStore!
    private var lifecycleStore: FakeLifecycleStore!
    private var biometryManager: FakeBiometryManager!
    private var scheduler = TestScheduler(initialClock: 0)
    private var disposeBag = DisposeBag()
    var subject: WelcomePresenter!

    override func spec() {

        describe("LoginPresenter") {
            beforeEach {
                self.view = FakeWelcomeView()
                self.view.firstTimeMessageHiddenStub = self.scheduler.createObserver(Bool.self)
                self.view.firstTimeLearnMoreHiddenStub = self.scheduler.createObserver(Bool.self)
                self.view.loginButtonHiddenStub = self.scheduler.createObserver(Bool.self)
                self.view.biometricButtonHiddenStub = self.scheduler.createObserver(Bool.self)
                self.view.biometricLabelHiddenStub = self.scheduler.createObserver(Bool.self)
                self.view.biometricImageNameStub = self.scheduler.createObserver(String.self)
                self.view.biometricButtonTitleStub = self.scheduler.createObserver(String?.self)

                self.routeActionHandler = FakeRouteActionHandler()
                self.dataStoreActionHandler = FakeDataStoreActionHandler()
                self.linkActionHandler = FakeLinkActionHandler()
                self.userInfoStore = FakeUserInfoStore()
                self.dataStore = FakeDataStore()
                self.lifecycleStore = FakeLifecycleStore()
                self.biometryManager = FakeBiometryManager()
                self.subject = WelcomePresenter(
                        view: self.view,
                        routeActionHandler: self.routeActionHandler,
                        dataStoreActionHandler: self.dataStoreActionHandler,
                        linkActionHandler: self.linkActionHandler,
                        userInfoStore: self.userInfoStore,
                        dataStore: self.dataStore,
                        lifecycleStore: self.lifecycleStore,
                        biometryManager: self.biometryManager
                )
            }

            describe("onViewReady") {
                describe("when the device is unlocked (first time login)") {
                    beforeEach {
                        self.biometryManager.deviceAuthAvailableStub = true
                        self.dataStore.fakeLocked.onNext(false)
                        self.subject.onViewReady()
                    }

                    it("shows the first time login message and the fxa login button") {
                        expect(self.view.firstTimeMessageHiddenStub.events.last!.value.element).to(beFalse())
                        expect(self.view.loginButtonHiddenStub.events.last!.value.element).to(beFalse())
                        expect(self.view.firstTimeLearnMoreHiddenStub.events.last!.value.element).to(beFalse())
                    }

                    it("hides the biometrics login button and label") {
                        expect(self.view.biometricButtonHiddenStub.events.last!.value.element).to(beTrue())
                        expect(self.view.biometricLabelHiddenStub.events.last!.value.element).to(beTrue())
                    }
                }

                describe("receiving a login button press") {
                    describe("when the user has device authentication available") {
                        beforeEach {
                            self.biometryManager.deviceAuthAvailableStub = true
                            self.subject.onViewReady()
                            self.view.fakeLoginButtonPress.onNext(())
                        }

                        it("dispatches the fxa login route action") {
                            expect(self.routeActionHandler.invokeArgument).notTo(beNil())
                            let argument = self.routeActionHandler.invokeArgument as! LoginRouteAction
                            expect(argument).to(equal(LoginRouteAction.fxa))
                        }
                    }

                    describe("when the user does not have device authentication available") {
                        beforeEach {
                            self.biometryManager.deviceAuthAvailableStub = false
                            self.subject.onViewReady()
                            self.view.fakeLoginButtonPress.onNext(())
                        }

                        it("displays a directional / informative alert") {
                            expect(self.view.alertControllerTitle).to(equal(Constant.string.notUsingPasscode))
                            expect(self.view.alertControllerMessage).to(equal(Constant.string.passcodeInformation))
                            expect(self.view.alertControllerStyle).to(equal(UIAlertControllerStyle.alert))
                        }

                        describe("tapping the Skip button") {
                            beforeEach {
                                self.view.alertControllerButtons![0].tapObserver!.onNext(())
                            }

                            it("dispatches the fxa login route action") {
                                expect(self.routeActionHandler.invokeArgument).notTo(beNil())
                                let argument = self.routeActionHandler.invokeArgument as! LoginRouteAction
                                expect(argument).to(equal(LoginRouteAction.fxa))
                            }
                        }

                        describe("tapping the set passcode button") {
                            beforeEach {
                                self.view.alertControllerButtons![1].tapObserver!.onNext(())
                            }

                            it("routes to the touchid / passcode settings page") {
                                let action = self.linkActionHandler.invokeArgument as! SettingLinkAction
                                expect(action).to(equal(SettingLinkAction.touchIDPasscode))
                            }
                        }
                    }
                }

                describe("receiving a learn more button press") {
                    beforeEach {
                        self.biometryManager.deviceAuthAvailableStub = true
                        self.subject.onViewReady()
                        self.view.fakeFxAButtonPress.onNext(())
                    }

                    it("dispatches the learn more route action") {
                        expect(self.routeActionHandler.invokeArgument).notTo(beNil())
                        let argument = self.routeActionHandler.invokeArgument as! ExternalWebsiteRouteAction
                        expect(argument).to(equal(ExternalWebsiteRouteAction(
                                urlString: Constant.app.useLockboxFAQ,
                                title: Constant.string.learnMore,
                                returnRoute: LoginRouteAction.welcome)))
                    }
                }

                describe("when the device is locked") {
                    let email = "example@example.com"

                    describe("when the profileinfo has an email address") {
                        beforeEach {
                            self.biometryManager.deviceAuthAvailableStub = true
                            self.subject.onViewReady()
                            self.dataStore.fakeLocked.onNext(true)
                            self.userInfoStore.fakeProfileInfo.onNext(ProfileInfo.Builder().email(email).build())
                        }

                        it("hides the first time login message and the fxa login button") {
                            expect(self.view.firstTimeMessageHiddenStub.events.last!.value.element).to(beTrue())
                            expect(self.view.loginButtonHiddenStub.events.last!.value.element).to(beTrue())
                            expect(self.view.firstTimeLearnMoreHiddenStub.events.last!.value.element).to(beTrue())
                        }

                        it("shows the biometrics login button and label") {
                            expect(self.view.biometricButtonHiddenStub.events.last!.value.element).to(beFalse())
                            expect(self.view.biometricLabelHiddenStub.events.last!.value.element).to(beFalse())
                        }

                        describe("when device authentication is available") {
                            describe("foregrounding actions") {
                                beforeEach {
                                    self.lifecycleStore.fakeCycle.onNext(LifecycleAction.foreground)
                                }

                                it("starts authentication") {
                                    expect(self.biometryManager.authMessage).to(equal(email))
                                }

                                describe("successful authentication") {
                                    beforeEach {
                                        self.biometryManager.fakeAuthResponse.onNext(())
                                    }

                                    it("unlocks the application") {
                                        expect(self.dataStoreActionHandler.invokeArgument).to(equal(DataStoreAction.unlock))
                                        expect(self.routeActionHandler.invokeArgument).to(beNil())
                                    }
                                }

                                describe("unsuccessful authentication") {
                                    beforeEach {
                                        self.biometryManager.fakeAuthResponse.onError(NSError(domain: "localauthentication", code: -1))
                                    }

                                    it("does nothing") {
                                        expect(self.routeActionHandler.invokeArgument).to(beNil())
                                        expect(self.dataStoreActionHandler.invokeArgument).to(beNil())
                                    }
                                }
                            }

                            describe("pressing the biometrics button") {
                                beforeEach {
                                    self.view.fakeBiometricButtonPress.onNext(())
                                }

                                it("starts authentication") {
                                    expect(self.biometryManager.authMessage).to(equal(email))
                                }

                                describe("successful authentication") {
                                    beforeEach {
                                        self.biometryManager.fakeAuthResponse.onNext(())
                                    }

                                    it("unlocks the application") {
                                        expect(self.dataStoreActionHandler.invokeArgument).to(equal(DataStoreAction.unlock))
                                        expect(self.routeActionHandler.invokeArgument).to(beNil())
                                    }
                                }

                                describe("unsuccessful authentication") {
                                    beforeEach {
                                        self.biometryManager.fakeAuthResponse.onError(NSError(domain: "localauthentication", code: -1))
                                    }

                                    it("does nothing") {
                                        expect(self.routeActionHandler.invokeArgument).to(beNil())
                                        expect(self.dataStoreActionHandler.invokeArgument).to(beNil())
                                    }
                                }
                            }
                        }

                        describe("when device authentication is not available") {
                            beforeEach {
                                self.biometryManager.deviceAuthAvailableStub = false
                                self.lifecycleStore.fakeCycle.onNext(LifecycleAction.foreground)
                            }

                            it("unlocks the device blindly") {
                                expect(self.dataStoreActionHandler.invokeArgument).to(equal(DataStoreAction.unlock))
                                expect(self.routeActionHandler.invokeArgument).to(beNil())
                            }
                        }
                    }

                    describe("when the profileinfo does not exist") {
                        beforeEach {
                            self.biometryManager.deviceAuthAvailableStub = true
                            self.subject.onViewReady()
                            self.dataStore.fakeLocked.onNext(true)
                            self.userInfoStore.fakeProfileInfo.onNext(nil)
                        }

                        it("hides the first time login message and the fxa login button") {
                            expect(self.view.firstTimeMessageHiddenStub.events.last!.value.element).to(beTrue())
                            expect(self.view.loginButtonHiddenStub.events.last!.value.element).to(beTrue())
                            expect(self.view.firstTimeLearnMoreHiddenStub.events.last!.value.element).to(beTrue())
                        }

                        it("shows the biometrics login button and label") {
                            expect(self.view.biometricButtonHiddenStub.events.last!.value.element).to(beFalse())
                            expect(self.view.biometricLabelHiddenStub.events.last!.value.element).to(beFalse())
                        }

                        describe("when device authentication is available") {
                            describe("foregrounding actions") {
                                beforeEach {
                                    self.lifecycleStore.fakeCycle.onNext(LifecycleAction.foreground)
                                }

                                it("starts authentication") {
                                    expect(self.biometryManager.authMessage).to(equal(Constant.string.unlockPlaceholder))
                                }

                                describe("successful authentication") {
                                    beforeEach {
                                        self.biometryManager.fakeAuthResponse.onNext(())
                                    }

                                    it("unlocks the application") {
                                        expect(self.dataStoreActionHandler.invokeArgument).to(equal(DataStoreAction.unlock))
                                        expect(self.routeActionHandler.invokeArgument).to(beNil())
                                    }
                                }

                                describe("unsuccessful authentication") {
                                    beforeEach {
                                        self.biometryManager.fakeAuthResponse.onError(NSError(domain: "localauthentication", code: -1))
                                    }

                                    it("does nothing") {
                                        expect(self.routeActionHandler.invokeArgument).to(beNil())
                                        expect(self.dataStoreActionHandler.invokeArgument).to(beNil())
                                    }
                                }
                            }

                            describe("pressing the biometrics button") {
                                beforeEach {
                                    self.view.fakeBiometricButtonPress.onNext(())
                                }

                                it("starts authentication") {
                                    expect(self.biometryManager.authMessage).to(equal(Constant.string.unlockPlaceholder))
                                }

                                describe("successful authentication") {
                                    beforeEach {
                                        self.biometryManager.fakeAuthResponse.onNext(())
                                    }

                                    it("unlocks the application") {
                                        expect(self.dataStoreActionHandler.invokeArgument).to(equal(DataStoreAction.unlock))
                                        expect(self.routeActionHandler.invokeArgument).to(beNil())
                                    }
                                }

                                describe("unsuccessful authentication") {
                                    beforeEach {
                                        self.biometryManager.fakeAuthResponse.onError(NSError(domain: "localauthentication", code: -1))
                                    }

                                    it("does nothing") {
                                        expect(self.routeActionHandler.invokeArgument).to(beNil())
                                        expect(self.dataStoreActionHandler.invokeArgument).to(beNil())
                                    }
                                }
                            }
                        }

                        describe("when device authentication is not available") {
                            beforeEach {
                                self.biometryManager.deviceAuthAvailableStub = false
                                self.lifecycleStore.fakeCycle.onNext(LifecycleAction.foreground)
                            }

                            it("unlocks the device blindly") {
                                expect(self.dataStoreActionHandler.invokeArgument).to(equal(DataStoreAction.unlock))
                                expect(self.routeActionHandler.invokeArgument).to(beNil())
                            }
                        }
                    }

                    describe("biometrics button title and image") {
                        describe("when device authentication is available but toucHID and faceID are not") {
                            beforeEach {
                                self.biometryManager.deviceAuthAvailableStub = true
                                self.subject.onViewReady()
                            }

                            it("displays the PIN prompt and image") {
                                expect(self.view.biometricImageNameStub.events.last!.value.element).to(equal("unlock"))
                                expect(self.view.biometricButtonTitleStub.events.last!.value.element).to(equal(Constant.string.unlockPIN))
                            }
                        }

                        describe("when touchID is available") {
                            beforeEach {
                                self.biometryManager.deviceAuthAvailableStub = true
                                self.biometryManager.touchIDStub = true
                                self.subject.onViewReady()
                            }

                            it("displays the touch ID prompt and image") {
                                expect(self.view.biometricImageNameStub.events.last!.value.element).to(equal("fingerprint"))
                                expect(self.view.biometricButtonTitleStub.events.last!.value.element).to(equal(Constant.string.unlockTouchID))
                            }
                        }

                        describe("when faceID is available") {
                            beforeEach {
                                self.biometryManager.deviceAuthAvailableStub = true
                                self.biometryManager.faceIDStub = true
                                self.subject.onViewReady()
                            }

                            it("displays the face ID prompt and image") {
                                expect(self.view.biometricImageNameStub.events.last!.value.element).to(equal("face"))
                                expect(self.view.biometricButtonTitleStub.events.last!.value.element).to(equal(Constant.string.unlockFaceID))
                            }
                        }
                    }
                }
            }
        }
    }
}
