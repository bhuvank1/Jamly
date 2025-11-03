//
//  LoginViewController.swift
//  Jamly
//
//  Created by Mitra, Monita on 10/14/25.
//

import UIKit
import FirebaseAuth

class LoginViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var accountSubtitle: UILabel!
    @IBOutlet weak var accountTitle: UILabel!
    @IBOutlet weak var registerButton: UIButton!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var segCtrl: UISegmentedControl!
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        emailField.delegate = self
        passwordField.delegate = self

        emailField.placeholder = "Enter your email"
        passwordField.placeholder = "Enter your password"
        passwordField.isSecureTextEntry = true
        
        loginButton.isHidden = false
        registerButton.isHidden = true
        accountTitle.text = "Sign In"
        accountSubtitle.text = "Enter your email and password"
        
        // watches for a change in login status
        Auth.auth().addStateDidChangeListener() {
            (auth, user) in
            if user != nil {
                self.performSegue(withIdentifier: "loginToAppSegue", sender: nil)
                self.emailField.text = ""
                self.passwordField.text = ""
            }
        }
    }
    
    @IBAction func segCtrlChanged(_ sender: Any) {
        switch segCtrl.selectedSegmentIndex {
        case 0:
            loginButton.isHidden = false
            registerButton.isHidden = true
            accountTitle.text = "Sign In"
            accountSubtitle.text = "Enter your email and password"
        case 1:
            loginButton.isHidden = true
            registerButton.isHidden = false
            accountTitle.text = "Create Account"
            accountSubtitle.text = "Enter your credentials to sign up for Jamly"
        default:
            print("user made unexpected choice!")
        }
        
    }
    
    @IBAction func loginButtonPressed(_ sender: Any) {
        Auth.auth().signIn(withEmail: emailField.text!, password: passwordField.text!) {
            (authResult, error) in
            if let error = error as NSError? {
                self.makePopup(popupTitle: "Error", popupMessage: error.localizedDescription)
            }
        }
    }
    
    
    @IBAction func createAccountButtonTapped(_ sender: Any) {
        Auth.auth().createUser(withEmail: emailField.text!, password: passwordField.text!) {
            (authResult, error) in
            if let error = error as NSError? {
                self.makePopup(popupTitle: "Error", popupMessage: error.localizedDescription)
            }
        }
    }
    
    // Called when 'return' key pressed
    func textFieldShouldReturn(_ textField:UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // Called when the user clicks on the view outside of the UITextField
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }

    func makePopup(popupTitle:String, popupMessage:String) {
            
            let controller = UIAlertController(
                title: popupTitle,
                message: popupMessage,
                preferredStyle: .alert)
            
            controller.addAction(UIAlertAction(title: "OK", style: .default))
            present(controller,animated:true)
        }

}
