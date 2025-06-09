//
//  Loader.swift
//  GolfAppDemo
//
//  Created by Kavin's Macbook on 22/05/25.
//

import UIKit


/// A singleton utility class to show and hide a global loading indicator overlay.
final class Loader {

    // MARK: - Singleton
    static let shared = Loader()
    
    // MARK: - Private Properties
    private var loader: UIActivityIndicatorView?
    private var backgroundView: UIView?
    
    private init() {} // Prevent external instantiation

    // MARK: - Show Loader
    
    /// Displays a semi-transparent fullscreen loader with a spinning indicator
    func showLoader() {
        DispatchQueue.main.async {
            // Ensure loader is not already showing
            guard self.loader == nil else { return }

            // Safely get the current active window
            guard let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }),
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
                return
            }

            // Create a dimmed background view
            let bgView = UIView(frame: window.bounds)
            bgView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
            bgView.isUserInteractionEnabled = true // Prevent touches underneath
            
            // Create and configure the loader
            let indicator = UIActivityIndicatorView(style: .large)
            indicator.center = bgView.center
            indicator.color = .white
            indicator.startAnimating()
            
            // Add to hierarchy
            bgView.addSubview(indicator)
            window.addSubview(bgView)
            
            // Keep references for hiding later
            self.loader = indicator
            self.backgroundView = bgView
        }
    }

    // MARK: - Hide Loader
    
    /// Hides the loader if currently visible
    func hideLoader() {
        DispatchQueue.main.async {
            self.loader?.stopAnimating()
            self.backgroundView?.removeFromSuperview()
            self.loader = nil
            self.backgroundView = nil
        }
    }
}
