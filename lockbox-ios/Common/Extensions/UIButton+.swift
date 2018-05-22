/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

extension UIButton {
    /**
     Initializes a new button with a title and an optional image. The title is
     set to white in the normal state and light grey when selected or
     highlighted. The image is set not to adjust when highlighted.  When an
     image is set, a left edge inset of 5 and a right edge outset of 20 are
     applied to the title.
     
     - Parameters:
        - title: The title for the button
        - imageName: The name of an image
     
     - Returns: A button with the title and image.
     */
    convenience init(title: String, imageName: String?) {
        self.init()

        self.setTitle(title, for: .normal)
        self.setTitleColor(.white, for: .normal)
        self.setTitleColor(Constant.color.lightGrey, for: .selected)
        self.setTitleColor(Constant.color.lightGrey, for: .highlighted)

        if let name = imageName {
            let backImage = UIImage(named: name)
            self.setImage(backImage, for: .normal)
            self.adjustsImageWhenHighlighted = false

            self.titleEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: -20)
        }

        self.sizeToFit()
    }
}
