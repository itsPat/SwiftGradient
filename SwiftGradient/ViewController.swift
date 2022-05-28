//
//  ViewController.swift
//  SwiftGradient
//
//  Created by Pat Trudel on 5/28/22.
//

import UIKit

class ViewController: UIViewController {
    
    let gradientView = GradientView(frame: .zero)
    var currentIndex = 0
    var configurations: [Configuration] = [
        .sweep(center: CGPoint(x: 0.5, y: 0.5), angle: 45),
        .radial(center: CGPoint(x: 0.5, y: 0.5), radius: 1.0),
        .spiral(center: CGPoint(x: 0.5, y: 0.5), angle: 45.0, scale: 2.0)
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        gradientView.frame = view.bounds
        view.addSubview(gradientView)
        gradientView.gradient = Gradient(
            colors: [
                CGColor(red: 252/255, green: 0/255, blue: 255/255, alpha: 1.0),
                CGColor(red: 0/255, green: 219/255, blue: 222/255, alpha: 1.0)
            ],
            locations: [0, 1]
        )
        updateCurrentGradient()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        updateCurrentGradient()
    }
    
    func updateCurrentGradient() {
        guard currentIndex < configurations.count else {
            currentIndex = 0
            return updateCurrentGradient()
        }
        let config = configurations[currentIndex]
        currentIndex += 1
        gradientView.configuration = config
    }

}

