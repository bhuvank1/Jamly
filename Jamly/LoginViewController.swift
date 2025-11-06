//
//  LoginViewController.swift
//  Jamly
//
//  Created by Mitra, Monita on 10/14/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class LoginViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var accountSubtitle: UILabel!
    @IBOutlet weak var accountTitle: UILabel!
    @IBOutlet weak var registerButton: UIButton!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var segCtrl: UISegmentedControl!
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var usernameField: UITextField!
    
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
        
        usernameField.isHidden = true
        
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
            usernameField.isHidden = false
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
        if (usernameField.text!.isEmpty) {
            self.makePopup(popupTitle: "Error", popupMessage: "Add a username to continue.")
            return
        }
        
        Auth.auth().createUser(withEmail: emailField.text!, password: passwordField.text!) {
            (authResult, error) in
            if let error = error as NSError? {
                self.makePopup(popupTitle: "Error", popupMessage: error.localizedDescription)
            } else {
                // retrive username
                guard let user = Auth.auth().currentUser else {return}
                // Use profile change request to update display name
                            let changeRequest = user.createProfileChangeRequest()
                            changeRequest.displayName = self.usernameField.text
                changeRequest.commitChanges { error in
                    if let error = error {
                        print("Error setting display name: \(error.localizedDescription)")
                    } else {
                        print("Display name successfully set to \(self.usernameField.text ?? "")")
                    }
                }
                
                // create userinfo database and store display name
                let uid = user.uid
                let email = user.email
                let displayName = self.usernameField.text
                let userData: [String: Any] = ["name": "", "email": email, "mobileNumber": "", "displayName": displayName, "friends" :[]]
                
                let db = Firestore.firestore()
                db.collection("userInfo").document(uid).setData(userData) { (error) in
                    if let error = error {
                        print("Error adding document: \(error)")
                    } else {
                        print("Document successfully added.")
                    }
                }
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
