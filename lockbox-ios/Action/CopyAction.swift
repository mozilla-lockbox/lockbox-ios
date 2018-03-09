/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import UIKit

struct CopyAction: Action {
    let text: String
    let fieldName: String
}

extension CopyAction: Equatable {
    static func ==(lhs: CopyAction, rhs: CopyAction) -> Bool {
        return lhs.text == rhs.text &&
                lhs.fieldName == rhs.fieldName
    }
}

struct CopyConfirmationDisplayAction: Action {
    let fieldName: String
}

extension CopyConfirmationDisplayAction: Equatable {
    static func ==(lhs: CopyConfirmationDisplayAction, rhs: CopyConfirmationDisplayAction) -> Bool {
        return lhs.fieldName == rhs.fieldName
    }
}

class CopyActionHandler: ActionHandler {
    static let shared = CopyActionHandler()

    private let dispatcher: Dispatcher
    private let pasteboard: UIPasteboard

    init(dispatcher: Dispatcher = Dispatcher.shared,
         pasteboard: UIPasteboard = UIPasteboard.general) {
        self.dispatcher = dispatcher
        self.pasteboard = pasteboard
    }

    func invoke(_ action: CopyAction) {
        self.pasteboard.string = action.text
        self.dispatcher.dispatch(action: CopyConfirmationDisplayAction(fieldName: action.fieldName))
    }
}
