//
//  RoutingiOS.swift
//  Routing
//
//  Created by Jason Prasad on 5/31/16.
//  Copyright © 2016 Routing. All rights reserved.
//

import UIKit
import QuartzCore

public enum ControllerSource {
    case Storyboard(storyboard: String, identifier: String, bundle: NSBundle?)
    case Nib(controller: UIViewController.Type, name: String?, bundle: NSBundle?)
    case Provided(() -> UIViewController)
}

public enum PresentationStyle {
    case Show
    case ShowDetail
    case Present(animated: Bool)
    case Push(animated: Bool)
    case Custom(custom: (presenting: UIViewController,
        presented: UIViewController,
        completed: Completed) -> Void)
}

public typealias PresentationSetup = (UIViewController, Parameters) -> UIViewController

internal protocol ViewControllerIterator {
    func nextViewController() -> UIViewController?
}

extension UITabBarController {
    internal override func nextViewController() -> UIViewController? {
        return selectedViewController
    }
}

extension UINavigationController {
    internal override func nextViewController() -> UIViewController? {
        return visibleViewController
    }
}

extension UIViewController : ViewControllerIterator {
    internal func nextViewController() -> UIViewController? {
        return presentedViewController
    }
}

public extension Routing {
    
    /**
     Associates a view controller presentation to a string pattern. A Routing instance present the
     view controller in the event of a matching URL using #open. Routing will only execute the first
     matching mapped route. This will be the last route added with #map.
     
     ```code
     let router = Routing()
     router.map("routingexample://route",
        instance: .Storyboard(storyboard: "Main", identifier: "ViewController", bundle: nil),
        style: .Present(animated: true)) { vc, parameters in
            ... // Useful callback for setup such as embedding in navigation controller
            return vc
     }
     ```
     
     - Parameter pattern:  A String pattern
     - Parameter source: The source of the view controller instance
     - Parameter style:  The presentation style in presenting the view controller
     - Parameter setup:  A closure provided for additional setup
     */
    
    public func map(pattern: String,
                    source: ControllerSource,
                    style: PresentationStyle = .Show,
                    setup: PresentationSetup? = nil) {
        let routeHandler: RouteHandler = { [unowned self] (route, parameters, completed) in
            guard let root = UIApplication.sharedApplication().keyWindow?.rootViewController else {
                completed()
                return
            }
            
            let strongSelf = self
            var vc = strongSelf.controller(from: source)
            
            if let setup = setup {
                vc = setup(vc, parameters)
            }
            
            var presenter = root
            while let nextVC = presenter.nextViewController() {
                presenter = nextVC
            }
        }
        
        self.map(pattern, handler: routeHandler)
    }
    
    private func controller(from source: ControllerSource) -> UIViewController {
        switch source {
        case let .Storyboard(storyboard, identifier, bundle):
            let storyboard = UIStoryboard(name: storyboard, bundle: bundle)
            return storyboard.instantiateViewControllerWithIdentifier(identifier)
        case let .Nib(controller , name, bundle):
            return controller.init(nibName: name, bundle: bundle)
        case let .Provided(provider):
            return provider()
        }
    }
    
    private func showController(presented: UIViewController,
                                from presenting: UIViewController,
                                     with style: PresentationStyle,
                                          completion: Completed) {
        switch style {
        case .Show:
            self.commitTransaction(completion) {
                presenting.showViewController(presented, sender: self)
            }
            break
        case .ShowDetail:
            self.commitTransaction(completion) {
                presenting.showDetailViewController(presented, sender: self)
            }
            break
        case let .Present(animated):
            presenting.presentViewController(presented, animated: animated, completion: completion)
            break
        case let .Push(animated) where presenting.isKindOfClass(UINavigationController):
            self.commitTransaction(completion) {
                (presenting as? UINavigationController)?.pushViewController(presented, animated: animated)
            }
        case let .Push(animated) where presenting.navigationController != nil:
            self.commitTransaction(completion) {
                presenting.navigationController?.pushViewController(presented, animated: animated)
            }
            break
        case let .Custom(custom):
            custom(presenting: presenting, presented: presented, completed: completion)
            break
        default:
            completion()
            break
        }
        
    }
    
    private func commitTransaction(completed: Completed, transition: () -> Void) {
        CATransaction.begin()
        CATransaction.setCompletionBlock(completed)
        transition()
        CATransaction.commit()
    }
}