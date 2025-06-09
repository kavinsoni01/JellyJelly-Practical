//
//  TabBarViewController.swift
//  JellyJellyTest
//
//  Created by Kavin's Macbook on 08/06/25.
//

import UIKit

class TabBarViewController: UITabBarController, UITabBarControllerDelegate {

    private let selectedIconScale: CGFloat = 1.2
    private let defaultIconScale: CGFloat = 1.0
    private let iconScaleAnimationDuration: TimeInterval = 0.15

    private var previousSelectedIndex: Int = 0

    private let backgroundViewTag = 9876 // Unique tag for our custom background
    private let selectedTabBackgroundColor = UIColor.systemBlue.withAlphaComponent(0.2) // Customize as needed
    private let backgroundViewCornerRadius: CGFloat = 12 // Customize as needed
    private let backgroundViewInsets = UIEdgeInsets(top: 6, left: 3, bottom: -4, right: 3) // Insets for the background

    override func viewDidLoad() {
        super.viewDidLoad()

        self.delegate = self
        tabBar.backgroundColor = .white
        tabBar.tintColor = .clear
        tabBar.unselectedItemTintColor = .clear

        setupViewControllers()
        
        self.previousSelectedIndex = self.selectedIndex

        // Ensure items exist and selectedIndex is valid before accessing
        if let items = tabBar.items, selectedIndex < items.count {
            let selectedItem = items[selectedIndex]
            applyIconScaling(to: selectedItem, scale: selectedIconScale)
            // Initial background setup might be deferred to viewDidAppear if item view frames are not ready
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Apply/update selection indicators once layout is certainly complete
        if let items = tabBar.items, selectedIndex < items.count {
            let currentSelectedItem = items[selectedIndex]
            // Ensure previously selected item (if different and exists) is reset
            if previousSelectedIndex != selectedIndex, previousSelectedIndex < items.count {
                 applyIconScaling(to: items[previousSelectedIndex], scale: defaultIconScale)
                 updateItemBackground(for: items[previousSelectedIndex], isSelected: false)
            }
            // Apply to current selected
            applyIconScaling(to: currentSelectedItem, scale: selectedIconScale)
            updateItemBackground(for: currentSelectedItem, isSelected: true)
        }
    }

    private func setupViewControllers() {
        guard let feedVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "FeedViewController") as? FeedViewController else {
            fatalError("Could not instantiate FeedViewController from storyboard.")
        }
        let feedNavController = UINavigationController(rootViewController: feedVC)
        feedNavController.tabBarItem = UITabBarItem(
            title: "",
            image: UIImage(named: "home")?.withRenderingMode(.alwaysOriginal),
            selectedImage: UIImage(named: "feed_selected")?.withRenderingMode(.alwaysOriginal)
        )
        feedNavController.tabBarItem.imageInsets = UIEdgeInsets(top: 6, left: 0, bottom: -6, right: 0)

        guard let cameraVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "CameraViewController") as? CameraViewController else {
            fatalError("Could not instantiate CameraViewController from storyboard.")
        }
        cameraVC.tabBarItem = UITabBarItem(
            title: "",
            image: UIImage(named: "camera")?.withRenderingMode(.alwaysOriginal),
            selectedImage: UIImage(named: "camera_selected")?.withRenderingMode(.alwaysOriginal)
        )
        cameraVC.tabBarItem.imageInsets = UIEdgeInsets(top: 6, left: 0, bottom: -6, right: 0)

        guard let cameraRollVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "CameraRollViewController") as? CameraRollViewController else {
            fatalError("Could not instantiate CameraRollViewController from storyboard.")
        }
        let cameraRollNavController = UINavigationController(rootViewController: cameraRollVC)
        cameraRollNavController.tabBarItem = UITabBarItem(
            title: "",
            image: UIImage(named: "gallary")?.withRenderingMode(.alwaysOriginal),
            selectedImage: UIImage(named: "gallary_selected")?.withRenderingMode(.alwaysOriginal)
        )
        cameraRollNavController.tabBarItem.imageInsets = UIEdgeInsets(top: 6, left: 0, bottom: -6, right: 0)

        self.viewControllers = [feedNavController, cameraVC, cameraRollNavController]
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard let items = tabBarController.tabBar.items else { return }
        let newSelectedIndex = viewControllers?.firstIndex(of: viewController) ?? 0

        if previousSelectedIndex < items.count && previousSelectedIndex != newSelectedIndex {
            applyIconScaling(to: items[previousSelectedIndex], scale: defaultIconScale)
            updateItemBackground(for: items[previousSelectedIndex], isSelected: false)
        }

        if newSelectedIndex < items.count {
            applyIconScaling(to: items[newSelectedIndex], scale: selectedIconScale)
            updateItemBackground(for: items[newSelectedIndex], isSelected: true)
        }
        
        previousSelectedIndex = newSelectedIndex
    }

    private func findIconImageView(in itemView: UIView) -> UIImageView? {
        if let swappableImageView = itemView.subviews.first(where: { NSStringFromClass(type(of: $0)) == "UITabBarSwappableImageView" }) as? UIImageView {
            return swappableImageView
        }
        // Fallback to find the first UIImageView, hoping it's the icon
        return itemView.subviews.compactMap({ $0 as? UIImageView }).first
    }

    private func applyIconScaling(to item: UITabBarItem, scale: CGFloat) {
        guard let itemView = item.value(forKey: "view") as? UIView,
              let iconImageView = findIconImageView(in: itemView) else {
            return
        }

        UIView.animate(withDuration: iconScaleAnimationDuration, delay: 0, options: .curveEaseInOut, animations: {
            iconImageView.transform = CGAffineTransform(scaleX: scale, y: scale)
        }, completion: nil)
    }

    private func updateItemBackground(for item: UITabBarItem, isSelected: Bool) {
        guard let itemView = item.value(forKey: "view") as? UIView else { return }

        var backgroundView = itemView.viewWithTag(backgroundViewTag)

        if isSelected {
            if backgroundView == nil {
                backgroundView = UIView()
                backgroundView!.tag = backgroundViewTag
                backgroundView!.backgroundColor = selectedTabBackgroundColor
                backgroundView!.layer.cornerRadius = backgroundViewCornerRadius
                backgroundView!.layer.masksToBounds = true
                // Add with autoresizing masks to adapt to itemView's size changes.
                backgroundView!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                itemView.insertSubview(backgroundView!, at: 0) // Insert at the back
            }
            // Set frame with insets. This needs to be done when itemView's frame is correct.
            backgroundView!.frame = itemView.bounds.inset(by: backgroundViewInsets)
            backgroundView?.isHidden = false
        } else {
            backgroundView?.isHidden = true // Hide instead of removing, for efficiency
        }
    }
}
