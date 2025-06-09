import UIKit

/// A utility class for presenting toast messages.
final class ToastPresenter {

    /// Shared singleton instance for easy access.
    static let shared = ToastPresenter()

    private init() {} // Private initializer to enforce singleton pattern.

    /// Displays a toast message on a given view.
    ///
    /// - Parameters:
    ///   - message: The text message to display in the toast.
    ///   - view: The `UIView` on which the toast will be presented.
    ///   - duration: The duration (in seconds) for which the toast will be visible. Defaults to 2.0 seconds.
    ///   - positionAnchor: An optional `UIView` to anchor the toast's bottom position relative to its top.
    ///                     If `nil`, the toast is positioned near the bottom of the `view`.
    ///   - completion: An optional closure called after the toast has fully disappeared.
    func showToast(
        message: String,
        on view: UIView,
        duration: TimeInterval = 2.0,
        anchorToTopOf positionAnchorView: UIView? = nil, // For positioning relative to another view
        completion: (() -> Void)? = nil
    ) {
        // Ensure UI updates are on the main thread.
        DispatchQueue.main.async {
            // Remove any existing toast with the same tag to prevent overlap.
            view.subviews.filter { $0.tag == 999 }.forEach { $0.removeFromSuperview() }

            let toastContainer = UIView()
            toastContainer.tag = 999 // Tag to identify and remove existing toasts.
            toastContainer.backgroundColor = UIColor.black.withAlphaComponent(0.75)
            toastContainer.alpha = 0.0 // Start transparent for fade-in animation.
            toastContainer.layer.cornerRadius = 10
            toastContainer.clipsToBounds = true
            toastContainer.translatesAutoresizingMaskIntoConstraints = false
            
            let toastLabel = UILabel()
            toastLabel.textColor = UIColor.white
            toastLabel.font = UIFont.systemFont(ofSize: 15.0)
            toastLabel.textAlignment = .center
            toastLabel.text = message
            toastLabel.numberOfLines = 0 // Allow multi-line messages.
            toastLabel.translatesAutoresizingMaskIntoConstraints = false
            
            toastContainer.addSubview(toastLabel)
            view.addSubview(toastContainer) // Add to the specified presenting view.
            
            // Constraints for the toast label within its container.
            NSLayoutConstraint.activate([
                toastLabel.leadingAnchor.constraint(equalTo: toastContainer.leadingAnchor, constant: 15),
                toastLabel.trailingAnchor.constraint(equalTo: toastContainer.trailingAnchor, constant: -15),
                toastLabel.topAnchor.constraint(equalTo: toastContainer.topAnchor, constant: 10),
                toastLabel.bottomAnchor.constraint(equalTo: toastContainer.bottomAnchor, constant: -10),
            ])
            
            // Constraints for the toast container itself.
            var toastConstraints = [
                toastContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                toastContainer.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.85), // Max width
                toastContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 35) // Min height
            ]

            if let anchor = positionAnchorView {
                // Position above the anchor view.
                toastConstraints.append(toastContainer.bottomAnchor.constraint(equalTo: anchor.topAnchor, constant: -20))
            } else {
                // Default to bottom of the view's safe area if no anchor.
                toastConstraints.append(toastContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30))
            }
            NSLayoutConstraint.activate(toastConstraints)
            
            // Animate the toast's appearance and disappearance.
            UIView.animate(withDuration: 0.4, delay: 0.0, options: .curveEaseIn, animations: {
                toastContainer.alpha = 1.0 // Fade in.
            }, completion: { _ in
                UIView.animate(withDuration: 0.4, delay: duration, options: .curveEaseOut, animations: {
                    toastContainer.alpha = 0.0 // Fade out.
                }, completion: { _ in
                    toastContainer.removeFromSuperview() // Clean up.
                    completion?() // Call completion handler if provided.
                })
            })
        }
    }
}