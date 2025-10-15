//
//  LoginViewController.swift
//  Jamly
//
//  Created by Mitra, Monita on 10/14/25.
//

import UIKit
import FirebaseAuth

class LoginViewController: UIViewController {

    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        emailField.placeholder = "Enter your email"
        passwordField.placeholder = "Enter your password"
        passwordField.isSecureTextEntry = true
        
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
    
   
    @IBAction func loginButtonPressed(_ sender: Any) {
        Auth.auth().signIn(withEmail: emailField.text!, password: passwordField.text!) {
            (authResult, error) in
            if let error = error as NSError? {
                self.makePopup(popupTitle: "Error", popupMessage: error.localizedDescription)
            }
        }
    }
    
    @IBAction func createAccountButtonPressed(_ sender: Any) {
        self.performSegue(withIdentifier: "wantToCreateAccountSegue", sender: nil)
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
