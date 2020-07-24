//    Copyright 2020 Dmitry Rybakov
//
//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
//
//        http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.

import UIKit

extension CALayer {
    public func show(_ rects: [(UIColor, CGRect)]) {
        var layers = [CAShapeLayer]()
        rects.forEach { color, rect in
            let overlayLayer = CAShapeLayer()
            overlayLayer.fillColor = UIColor.clear.cgColor
            overlayLayer.strokeColor = color.cgColor
            let combined = CGMutablePath()
            let rectPath = UIBezierPath(roundedRect: rect, cornerRadius: 0.0)
            combined.addPath(rectPath.cgPath)
            overlayLayer.path = combined
            layers.append(overlayLayer)
        }
        self.sublayers?.forEach{ l in
            if l is CAShapeLayer {
                l.removeFromSuperlayer()
            }
        }
        layers.forEach { self.addSublayer($0) }
    }
}
