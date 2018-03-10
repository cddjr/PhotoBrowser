//
//  XButton.swift
//  JXPhotoBrowser
//
//  Created by 邓景仁 on 2018/3/10.
//

import Foundation

class XButton : UIButton {
    
    private let _height:CGFloat = 60
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.height < _height {
            let rc = self.bounds.insetBy(dx: 0, dy: -(_height-self.bounds.height)/2)
            if rc.contains(point) {
                return self
            } else {
                return nil
            }
        } else {
            return super.hitTest(point, with: event)
        }
    }
}
