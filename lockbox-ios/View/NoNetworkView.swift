/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import UIKit

class NoNetworkView: UIView {
    @IBOutlet weak var retryButton: UIButton!

    class func instanceFromNib() -> NoNetworkView {
        return UINib(nibName: "NoNetwork", bundle: nil)
            .instantiate(withOwner: nil, options: nil)[0] as! NoNetworkView // swiftlint:disable:this force_cast
    }
}
