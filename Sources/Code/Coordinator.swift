//
//  Coordinator.swift
//  Cruciverber
//
//  Created by Cihat Gündüz on 12.03.16.
//  Copyright © 2016 Flinesoft. All rights reserved.
//

import UIKit
import HandySwift

typealias ActionClosure = () -> ()

/// The different presentation options.
///
/// - Modal: Present modally with optional completion handler.
/// - Push: Push within navigation controller.
public enum PresentationStyle {
    case modal(completion: (() -> Void)?)
    case push
}

/// The base coordinator class helping to use the coordinator concept. A coordinators task is to control
/// the screen flow of views and controllers that belong together or are presented in a specific order
/// even if there is logic behind it. Simply put: Thanks to coordinators controllers responsibility now
/// is to only present the views – all decision logic and data handling should be part of the coordinator.
///
/// This class was inspired by the concept presented by Soroush Khanlou here:
/// http://khanlou.com/2015/10/coordinators-redux/
///
/// This class was **designed to be subclassed** (and will be abstract once Swift enables it).
/// All subclasses should override the following properties and methods:
///
///   - mainViewController
///   - start()
open class Coordinator {
    // MARK: - Stored Instance Properties

    /// The coordinators started from this coordinator.
    private var childCoordinators: [Coordinator] = []

    /// The coordinator who started this coordinator.
    private var parentCoordinator: Coordinator?

    /// The view controller to be presented from. Can be a UINavigationViewController.
    public let presentingViewController: UIViewController

    /// The current main view controller of the coordinator. Can be a UINavigationViewController.
    open var mainViewController: UIViewController? { return nil }

    private var finishClosure: (() -> Void)?
    private var disappearClosure: (() -> Void)?

    /// This can be used on didDisappear to assume a screen pan swipe or back button press.
    public var finishCalled = false


    // MARK: - Computed Instance Properties

    /// Returns the presenting navigation controller if available. Extracts the navigation controller
    /// from a UIViewController or directly returns a UINavigationController if such presenting.
    private var presentingNavigationController: UINavigationController? {
        if let presentingNavCtrl = self.presentingViewController as? UINavigationController {
            return presentingNavCtrl
        }
        return self.presentingViewController.navigationController
    }


    // MARK: - Initializers

    /// Initialize a new coordinator object.
    ///
    /// - Parameters:
    ///   - presentingViewController: The view controller (or the navigation controller) presenting the new coordinator.
    public init(presentingViewController: UIViewController) {
        self.presentingViewController = presentingViewController
    }


    // MARK: - Instance Methods

    /// Starts the screen flow represented by this coordinator. Subclasses should put their screen flow logic in here.
    open func start() {}

    /// Starts a sub coordinator from within this coordinator – no need to call `start()` on the coordinator manually.
    /// This ensures the sub coordinator is correctly added to the child coordinators array.
    ///
    /// - Parameters:
    ///   - subCoordinator: The sub coordinator to be started and added to the child coordinators.
    /// - Returns: The child coordinator object for consecutive callback definitions (like `onFinish`).
    public func start(subCoordinator childCoordinator: Coordinator) -> Coordinator {
        self.childCoordinators.append(childCoordinator)
        childCoordinator.parentCoordinator = self
        childCoordinator.start()
        return childCoordinator
    }

    /// Callback to be called when the coordinator finishes.
    ///
    /// - Parameters:
    ///    - closure: The callback to be called on finish.
    public func onFinish(_ closure: @escaping () -> Void) {
        self.finishClosure = closure
    }

    /// Callback to be called when the coordinators main view controller has disappeared.
    ///
    /// - Parameters:
    ///   - closure: The callback to be called on disappear.
    public func onDisappear(_ closure: @escaping () -> Void) {
        self.disappearClosure = closure
    }

    /// Finishes a sub coordinator and removes it from its parent coordinators child coordinators (if any).
    ///
    /// - Parameters:
    ///   - viewCtrl: The view controller to be finished.
    ///   - makeDisappear: Dismisses or pops the view controller if set to `true`.
    public func finish(alreadyDisappeared: Bool = false) {
        finishCalled = true

        if let parentCoordinator = self.parentCoordinator {
            let foundChildIndex = parentCoordinator.childCoordinators.index { $0 === self }
            if let childIndex = foundChildIndex {
                parentCoordinator.childCoordinators.remove(at: childIndex)
            }
        }

        if let finishClosure = self.finishClosure {
            finishClosure()
        }

        guard !alreadyDisappeared else { return }

        if let viewCtrl = mainViewController {
            if let navigationCtrl = viewCtrl.navigationController {
                if navigationCtrl.viewControllers.first == viewCtrl {
                    if let presentingViewCtrl = navigationCtrl.presentingViewController {
                        presentingViewCtrl.dismiss(animated: true, completion: disappearClosure)
                    } else {
                        // TODO: this case needed?
                        navigationCtrl.dismiss(animated: true, completion: disappearClosure)
                    }
                } else {
                    navigationCtrl.popViewController(animated: true)
                    if let disappearClosure = disappearClosure {
                        delay(bySeconds: 0.3, closure: disappearClosure)
                    }
                }
            } else {
                presentingViewController.dismiss(animated: true, completion: disappearClosure)
            }
        }
    }

    /// Presents a view controller given the specified presentation style.
    ///
    /// If no presentation style is given then it will be automatically detected by the following rules:
    ///   - `.Push` if the current controller has a navigation stack **and** the presented controller doesn't have one
    ///   - `.Modal(completion: nil)` otherwise
    ///
    /// - Parameters:
    ///   - viewController: The view controller to be presented.
    ///   - style: The expected presentation style. Defaults to automatic detection.
    public func present(_ viewCtrl: UIViewController, style: PresentationStyle? = nil, navigation: Bool = true) {
        let presentationStyle = style ?? automaticPresentationStyle(forViewController: viewCtrl)

        switch presentationStyle {
        case .modal(let completion):
            if let navigationCtrl = viewCtrl as? UINavigationController ?? viewCtrl.navigationController {
                self.presentingViewController.present(navigationCtrl, animated: true, completion: completion)
            } else if !navigation {
                // a view controller without navigation stack is passed, .modal style is chosen but navigation is false
                self.presentingViewController.present(viewCtrl, animated: true, completion: completion)
            } else {
                // a view controller without navigation stack is passed, .modal style is chosen and navigation is true
                let navigationCtrl = UINavigationController(rootViewController: viewCtrl)
                self.presentingViewController.present(navigationCtrl, animated: true, completion: completion)
            }

        case .push:
            self.presentingNavigationController?.pushViewController(viewCtrl, animated: true)
        }
    }

    /// Makes sure to call finish if not called yet after view disappeared.
    /// This should always be called in view controllers with back buttons to ensure they are finished correctly.
    ///
    /// - Parameters:
    ///   - viewCtrl: The view controller which disappeared.
    public func didDisappear() {
        if !finishCalled { finish(alreadyDisappeared: true) }
    }


    // MARK: - Helpers Methods

    private func automaticPresentationStyle(forViewController viewController: UIViewController) -> PresentationStyle {
        if self.presentingNavigationController == nil || viewController is UINavigationController || viewController.navigationController != nil {
            return .modal(completion: nil)
        }

        return .push
    }
}