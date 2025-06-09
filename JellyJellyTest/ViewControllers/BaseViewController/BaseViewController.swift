//
//  BaseViewController.swift
//  GolfAppDemo
//
//  Created by Kavin's Macbook on 22/05/25.
//

import UIKit

class BaseViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let textAttributes = [NSAttributedString.Key.foregroundColor:UIColor.black,NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20)]
        navigationController?.navigationBar.titleTextAttributes = textAttributes
        self.navigationController?.navigationBar.isTranslucent = true

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Make the navigation bar background clear
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.isTranslucent = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Restore the navigation bar to default
        navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
        navigationController?.navigationBar.shadowImage = nil
    }
    
    func setRightBarButton(img: UIImage?) {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(image: img?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(RightBarBtnAction))
    }
    
    func setRightBarButtonWithText(text: String?) {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: text, style: .plain, target: self, action: #selector(RightBarBtnAction))
    }
    func setLeftBarButton(img: UIImage?) {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem.init(image: img?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(leftBarBtnAction))
    }
    
    func hidenavigationBar(){
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    func showNavigationBar(){
        self.navigationController!.setNavigationBarHidden(false, animated: true)
    }
    
    func hideLeftBarBtn() {
        self.navigationItem.leftBarButtonItem = nil
    }
    
    func hideLeftSideButtonBack(){
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: " ", style: .plain, target: nil, action: nil)
    }
    func hiderightSideButtonBack(){
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: " ", style: .plain, target: nil, action: nil)
    }
    @objc func leftBarBtnAction() {
        print("left back")
        self.navigationController?.popViewController(animated: true)
        self.dismiss(animated: true, completion: nil)
    }
    @objc func RightBarBtnAction() {
        print("Right back")
        self.navigationController?.popViewController(animated: true)
        self.dismiss(animated: true, completion: nil)
    }
    
    
    func showAlert(title:String, message: String, on viewController: UIViewController) {
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(okAction)
        
        // Present the alert on the current view controller
        viewController.present(alert, animated: true, completion: nil)
    }
}
