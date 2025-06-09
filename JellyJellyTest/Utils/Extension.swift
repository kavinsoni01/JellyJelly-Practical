//
//  Extension.swift
//  GolfAppDemo
//
//  Created by Kavin's Macbook on 22/05/25.
//

import UIKit

extension UIViewController {
    
    enum AlertType {
        case alert
        case actionSheet
    }
    
    /// Show a customizable alert or action sheet
    ///
    /// - Parameters:
    ///   - title: The title of the alert
    ///   - message: The message of the alert
    ///   - type: The alert type (.alert or .actionSheet)
    ///   - actions: Array of action titles and their handlers
    ///   - cancelTitle: Optional cancel button title
    ///   - cancelHandler: Optional cancel action callback
    ///   
    func showAlert(
        title: String?,
        message: String?,
        type: AlertType = .alert,
        actions: [(title: String, style: UIAlertAction.Style, handler: (() -> Void)?)],
        cancelTitle: String? = nil,
        cancelHandler: (() -> Void)? = nil
    ) {
        let preferredStyle: UIAlertController.Style = (type == .alert) ? .alert : .actionSheet
        let alertController = UIAlertController(title: title, message: message, preferredStyle: preferredStyle)
        
        for action in actions {
            let alertAction = UIAlertAction(title: action.title, style: action.style) { _ in
                action.handler?()
            }
            alertController.addAction(alertAction)
        }
        
        if let cancelTitle = cancelTitle {
            let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel) { _ in
                cancelHandler?()
            }
            alertController.addAction(cancelAction)
        }
        
        // For iPad support when using action sheets
        if let popover = alertController.popoverPresentationController, preferredStyle == .actionSheet {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        self.present(alertController, animated: true)
    }
}

extension UITableView {

    /// Displays a styled empty view when no data is available
    /// - Parameters:
    ///   - title: Main title text
    ///   - message: Subtitle message
    ///   - image: Optional image
    ///
    func setEmptyView(title: String, message: String, image: UIImage?) {
        let emptyView = UIView(frame: CGRect(x: 0,
                                             y: 0,
                                             width: self.bounds.width,
                                             height: self.bounds.height))

        let imageView = UIImageView()
        let titleLabel = UILabel()
        let messageLabel = UILabel()

        imageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        imageView.contentMode = .scaleAspectFit
        imageView.image = image

        titleLabel.text = title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = .black
        titleLabel.textAlignment = .center

        messageLabel.text = message
        messageLabel.font = UIFont.systemFont(ofSize: 16)
        messageLabel.textColor = .darkGray
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center

        emptyView.addSubview(imageView)
        emptyView.addSubview(titleLabel)
        emptyView.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: emptyView.centerYAnchor, constant: -60),
            imageView.widthAnchor.constraint(equalToConstant: 120),
            imageView.heightAnchor.constraint(equalToConstant: 120),

            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: emptyView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: emptyView.trailingAnchor, constant: -20),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: emptyView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: emptyView.trailingAnchor, constant: -20)
        ])

        // Optional rotation animation
        if let _ = image {
            UIView.animate(withDuration: 0.6, delay: 0, options: [.autoreverse, .repeat], animations: {
                imageView.transform = CGAffineTransform(rotationAngle: .pi / 20)
            }, completion: nil)
        }

        self.backgroundView = emptyView
        self.separatorStyle = .none
    }
    /// Restores the table view to its default state

    func restore() {
        self.backgroundView = nil
        //self.separatorStyle = .singleLine
    }
}


extension UISearchBar {
    
    /// Adds a Done button to the keyboard for dismissing it
    func addDoneButtonOnKeyboard() {
        guard let textField = self.value(forKey: "searchField") as? UITextField else { return }

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self,
                                         action: #selector(dismissKeyboard))
        
        toolbar.items = [flexSpace, doneButton]
        textField.inputAccessoryView = toolbar
    }

    /// Dismisses the keyboard
    @objc private func dismissKeyboard() {
        self.resignFirstResponder()
    }
}
extension UIView {
    /// Adds a soft drop shadow to the view
    func addDropShadow(cornerRadius: CGFloat = 0) {
        self.layer.masksToBounds = false
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowRadius = 4
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.2
        
        if cornerRadius > 0 {
            self.layer.shadowPath = UIBezierPath(roundedRect: self.bounds, cornerRadius: cornerRadius).cgPath
        } else {
            self.layer.shadowPath = UIBezierPath(rect: self.bounds).cgPath
        }
    }
}
