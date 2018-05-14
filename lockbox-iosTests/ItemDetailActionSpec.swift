/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Quick
import Nimble
import RxSwift

@testable import Lockbox

class ItemDetailActionHandlerSpec: QuickSpec {

    class FakeDispatcher: Dispatcher {
        var dispatchedAction: Action?

        override func dispatch(action: Action) {
            self.dispatchedAction = action
        }
    }

    private var dispatcher: FakeDispatcher!
    var subject: ItemDetailActionHandler!

    override func spec() {
        describe("ItemDetailActionHandler") {
            beforeEach {
                self.dispatcher = FakeDispatcher()
                self.subject = ItemDetailActionHandler(dispatcher: self.dispatcher)
            }

            describe("invoke") {
                let action = ItemDetailDisplayAction.togglePassword(displayed: false)

                beforeEach {
                    self.subject.invoke(action)
                }

                it("passes the action to the dispatcher") {
                    expect(self.dispatcher.dispatchedAction).notTo(beNil())
                    let dispatchedAction = self.dispatcher.dispatchedAction as! ItemDetailDisplayAction
                    expect(dispatchedAction).to(equal(action))
                }
            }
        }

        describe("ItemDetailDisplayAction equality") {
            it("togglepassword is equal based on the bool value") {
                expect(ItemDetailDisplayAction.togglePassword(displayed: true))
                        .to(equal(ItemDetailDisplayAction.togglePassword(displayed: true)))
                expect(ItemDetailDisplayAction.togglePassword(displayed: true))
                        .notTo(equal(ItemDetailDisplayAction.togglePassword(displayed: false)))
            }
        }

        describe("telemetry") {
            it("event method should equal tap") {
                expect(ItemDetailDisplayAction.togglePassword(displayed: true).eventMethod).to(equal(TelemetryEventMethod.tap))
            }

            it("event object should equal revealPassword") {
                expect(ItemDetailDisplayAction.togglePassword(displayed: true).eventObject).to(equal(TelemetryEventObject.revealPassword))
            }
        }
    }
}
