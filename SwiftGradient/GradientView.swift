//
//  GradientView.swift
//  SwiftGradient
//
//  Created by Pat Trudel on 5/28/22.
//

import UIKit

/// A view that draws a color gradient over its background color,
/// filling the shape of the view (including rounded corners).
public class GradientView: UIView {
    public override class var layerClass: AnyClass {
        return GradientLayer.self
    }

    /// Layer's gradient.
    public var gradient: Gradient {
        get {
            return (self.layer as! GradientLayer).gradient
        }
        set {
            (self.layer as! GradientLayer).gradient = newValue
        }
    }

    /// Layer's gradient drawing configuration.
    public var configuration: Configuration {
        get {
            return (self.layer as! GradientLayer).configuration
        }
        set {
            (self.layer as! GradientLayer).configuration = newValue
        }
    }
}
