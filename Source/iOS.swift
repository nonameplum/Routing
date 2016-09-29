//
//  iOS.swift
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

public indirect enum PresentationStyle {
    case Show
    case ShowDetail
    case Present(animated: Bool)
    case Push(animated: Bool)
    case Custom(custom: (presenting: UIViewController,
        presented: UIViewController,
        completed: Completed) -> Void)
    case InNavigationController(PresentationStyle)
    case ReplaceRootController
}

public typealias PresentationSetup = (UIViewController, Parameters, Data?) -> Void

public typealias BackwardSetup = (UIViewController, String, Parameters, Data?) -> Void

public typealias BackwardHandler = (String, PresentationStyle, UIViewController, Completed) -> Void

public protocol RoutingPresentationSetup {
    func setup(route: String, parameters: Parameters, data: Data?)
}

public extension UINavigationController {
    public func pushViewController(vc: UIViewController, animated: Bool, completion: Completed) {
        self.commit(completion) {
            self.pushViewController(vc, animated: animated)
        }
    }

    public func popViewControllerAnimated(animated: Bool, completion: Completed) -> UIViewController? {
        var vc: UIViewController?
        self.commit(completion) {
            vc = self.popViewControllerAnimated(animated)
        }
        return vc
    }

    public func popToViewControllerAnimated(viewController: UIViewController, animated: Bool, completion: Completed) -> [UIViewController]? {
        var vc: [UIViewController]?
        self.commit(completion) {
            vc = self.popToViewController(viewController, animated: animated)
        }
        return vc
    }

    public func popToRootViewControllerAnimated(animated: Bool, completion: Completed) -> [UIViewController]? {
        var vc: [UIViewController]?
        self.commit(completion) {
            vc = self.popToRootViewControllerAnimated(animated)
        }
        return vc
    }
}

public extension UIViewController {
    public func showViewController(vc: UIViewController, sender: AnyObject?, completion: Completed) {
        self.commit(completion) {
            self.showViewController(vc, sender: sender)
        }
    }

    public func showDetailViewController(vc: UIViewController, sender: AnyObject?, completion: Completed) {
        self.commit(completion) {
            self.showDetailViewController(vc, sender: sender)
        }
    }

    private func commit(completed: Completed, transition: () -> Void) {
        CATransaction.begin()
        CATransaction.setCompletionBlock(completed)
        transition()
        CATransaction.commit()
    }
}

internal protocol ControllerIterator {
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

extension UIViewController : ControllerIterator {
    internal func nextViewController() -> UIViewController? {
        return presentedViewController
    }
}

internal struct HistoricalRoute {
    let route: String
    let parameters: Parameters
    let backwardSetup: BackwardSetup?
    let backwardHandler: BackwardHandler?
    let style: PresentationStyle
    weak var vc: UIViewController!
}

public class UIKitRouting: Routing {
    
    private weak var window: UIWindow!
    internal var historicalRoutes = [HistoricalRoute]()
    
    public init(window: UIWindow) {
        self.window = window
        
        super.init()
    }
    
    private convenience init(window: UIWindow, routes: [Route], targetQueue: dispatch_queue_t?) {
        self.init(window: window)
        self.routes = routes
        
        if let targetQueue = targetQueue {
            dispatch_set_target_queue(self.routingQueue, targetQueue)
        }
    }
    
    public override subscript(tags: String...) -> UIKitRouting {
        get {
            let set = Set(tags)
            return UIKitRouting(window: self.window, routes: self.routes.filter({ set.intersect($0.tags).isEmpty == false }), targetQueue: nil)
        }
    }
    
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
     - Parameter tag:  A tag to reference when subscripting a Routing object
     - Parameter owner: The routes owner. If deallocated the route will be removed.
     - Parameter source: The source of the view controller instance
     - Parameter style:  The presentation style in presenting the view controller
     - Parameter setup:  A closure provided for additional setup
     - Returns:  The RouteUUID
     */
    
    public func map(pattern: String,
                    tags: [String] = ["Views"],
                    owner: RouteOwner? = nil,
                    source: ControllerSource,
                    style: PresentationStyle = .Show,
                    backwardHandler: BackwardHandler? = nil,
                    backwardSetup: BackwardSetup? = nil,
                    setup: PresentationSetup? = nil) -> RouteUUID {
        let routeHandler: RouteHandler = { [unowned self] (route, parameters, data, completed) in
            let strongSelf = self
            
            let vc = strongSelf.controller(from: source)
            (vc as? RoutingPresentationSetup)?.setup(route, parameters: parameters, data: data)
            setup?(vc, parameters, data)
            
            var presenter: UIViewController
            
            if let root = self.window.rootViewController {
                presenter = root
                while let nextVC = presenter.nextViewController() {
                    presenter = nextVC
                }
                
                strongSelf.showController(vc, from: presenter, with: style, completion: completed)
            } else {
                self.window.rootViewController = vc
                if !self.window.keyWindow {
                    self.window.makeKeyWindow()
                }
            }
            
            let route = HistoricalRoute(route: route, parameters: parameters, backwardSetup: backwardSetup, backwardHandler: backwardHandler, style: style, vc: vc)
            
            if case PresentationStyle.ReplaceRootController = style {
                self.historicalRoutes.removeAll()
            }
            
            self.historicalRoutes.append(route)
        }
        
        return self.map(pattern, tags: tags, owner: owner, queue: dispatch_get_main_queue(), handler: routeHandler)
    }
    
    public func goBack(data: Data?) {
        historicalRoutes = historicalRoutes.filter { $0.vc != nil }
        
        guard let route = historicalRoutes.dropLast().last?.route else { return }
        
        goBack(route, data: data)
    }
    
    public func goBack(route: String, data: Data?) {
        historicalRoutes = historicalRoutes.filter { $0.vc != nil }
        
        guard historicalRoutes.count > 1,
            let currentRoute = historicalRoutes.last,
            let indexOfDestinationRoute = historicalRoutes.indexOf({ $0.route == route }) else { return }
        
        let destinationRoute = historicalRoutes[indexOfDestinationRoute]
        
        var routes = Array(historicalRoutes.suffixFrom(indexOfDestinationRoute))
        
        func call(_routes: [HistoricalRoute], finished: (() -> Void)?) {
            if let _route = _routes.last where _route.route != route {
                _route.backwardHandler?(destinationRoute.route, _route.style, _route.vc) {
                    call(Array(_routes.dropLast()), finished: finished)
                }
            } else {
                finished?()
            }
        }
        
        call(routes) { [unowned self] in
            self.historicalRoutes.removeLast(self.historicalRoutes.count - indexOfDestinationRoute - 1)
            destinationRoute.backwardSetup?(destinationRoute.vc, currentRoute.route, currentRoute.parameters, data)
        }
    }
    
    private func controller(from source: ControllerSource) -> UIViewController {
        switch source {
        case let .Storyboard(storyboard, identifier, bundle):
            let storyboard = UIStoryboard(name: storyboard, bundle: bundle)
            return storyboard.instantiateViewControllerWithIdentifier(identifier)
        case let .Nib(controller, name, bundle):
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
            presenting.showViewController(presented, sender: self, completion: completion)
            break
        case .ShowDetail:
            presenting.showDetailViewController(presented, sender: self, completion:  completion)
            break
        case let .Present(animated):
            presenting.presentViewController(presented, animated: animated, completion: completion)
            break
        case let .Push(animated):
            if let presenting = presenting as? UINavigationController {
                presenting.pushViewController(presented, animated: animated, completion: completion)
            } else {
                presenting.navigationController?.pushViewController(presented, animated: animated, completion: completion)
            }
        case let .Custom(custom):
            custom(presenting: presenting, presented: presented, completed: completion)
            break
        case let .InNavigationController(style):
            showController(UINavigationController(rootViewController: presented),
                           from: presenting,
                           with: style,
                           completion: completion)
            break
        case .ReplaceRootController:
            window.rootViewController = presented
        }
    }
}
