/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Quick
import Nimble
import RxTest
import RxSwift

@testable import Lockbox

class CopyStoreSpec: QuickSpec {
    class FakeDispatcher: Dispatcher {
        let fakeRegistration = PublishSubject<Action>()

        override var register: Observable<Action> {
            return self.fakeRegistration.asObservable()
        }
    }

    private var dispatcher: FakeDispatcher!
    private var scheduler = TestScheduler(initialClock: 0)
    private var disposeBag = DisposeBag()
    var subject: CopyDisplayStore!

    override func spec() {
        describe("CopyDisplayStore") {
            beforeEach {
                self.dispatcher = FakeDispatcher()
                self.subject = CopyDisplayStore(dispatcher: self.dispatcher)
            }

            describe("copyDisplay") {
                var displayObserver = self.scheduler.createObserver(CopyDisplayAction.self)

                beforeEach {
                    displayObserver = self.scheduler.createObserver(CopyDisplayAction.self)

                    self.subject.copyDisplay
                            .drive(displayObserver)
                            .disposed(by: self.disposeBag)
                }

                it("passes through CopyDisplayActions from the dispatcher") {
                    self.dispatcher.fakeRegistration.onNext(CopyDisplayAction(fieldName: "something"))

                    expect(displayObserver.events.count).to(equal(1))
                    expect(displayObserver.events.first!.value.element!).to(equal(CopyDisplayAction(fieldName: "something")))
                }

                it("does not pass through non-ItemDetailDisplayActions") {
                    self.dispatcher.fakeRegistration.onNext(LoginRouteAction.welcome)

                    expect(displayObserver.events.count).to(equal(0))
                }
            }
        }
    }
}
