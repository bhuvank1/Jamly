//
//  AccountSettingsVC.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 10/14/25.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth

class AccountSettingsVC: UIViewController{
    
    @IBOutlet weak var nameField: UITextField!
    
    @IBOutlet weak var emailField: UITextField!
    
    @IBOutlet weak var mobileNumberField: UITextField!
    
    @IBOutlet weak var nameText: UILabel!
    @IBOutlet weak var emailText: UILabel!
    @IBOutlet weak var spotifyButton: UIButton!
    
    let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        fetchUserInfo()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        checkSpotifyConnection()
    }
    
    func fetchUserInfo() {
        guard let user = Auth.auth().currentUser else {
            print("User is presently not signed in.")
            return
        }
        
        let uid = user.uid
        
        db.collection("userInfo").document(uid).getDocument { (document, error) in
            if let error = error {
                print("Error fetching document.")
                return
            }
            if let document = document, document.exists {
                let data = document.data()
                let name = data?["name"] as? String ?? "your name"
                let email = data?["email"] as? String ?? "youremail@gmail.com"
                
                DispatchQueue.main.async {
                    self.nameText.text = name
                    self.emailText.text = email
                }
            }
        }
    }
    
    @IBAction func saveButtonPressed(_ sender: Any) {
        // if at least one of the fields: name, email and number are not empty then add it to the database
        let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let email = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let mobileNumber = mobileNumberField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // Check if at least one field is not empty
        if !name.isEmpty || !email.isEmpty || !mobileNumber.isEmpty {
            // get user id to associate a user to their user info
            guard let user = Auth.auth().currentUser else { return
                print("No user is currently signed in.")
                return
            }
            
            let uid = user.uid
            let userData: [String: Any] = ["name": name, "email": email, "mobileNumber": mobileNumber]
            
            db.collection("userInfo").document(uid).setData(userData) { (error) in
                if let error = error {
                    print("Error adding document: \(error)")
                } else {
                    print("Document successfully added")
                }
            }
        } else {
            print("All fields are empty. Nothing to save.")
        }
        self.dismiss(animated: true)
    }
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        self.dismiss(animated: true)
    }
    
    @IBAction func spotifyButtonPressed(_ sender: Any) {
        SpotifyAuthManager.shared.signIn {
            success in DispatchQueue.main.async {
                if success {
                    
                    let alert = UIAlertController(title: "Connected 🎉", message: "You can now use Spotify features.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.setSpotifyButtonState(connected: true)
                } else {
                    let alert = UIAlertController(title: "Login Failed", message: "Please try again.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.spotifyButton.titleLabel?.text = "Failed"
                    self.present(alert, animated: true)
                    
                }
            }
        }
    }
    
    //Helper function to set spotify button state
    private func setSpotifyButtonState(connected: Bool) {
        if connected {
            spotifyButton.setTitle("Connected to Spotify", for: .normal)
            spotifyButton.backgroundColor = .systemGreen
        } else {
            spotifyButton.setTitle("Connect Spotify", for: .normal)
            spotifyButton.backgroundColor = .systemBlue
        }
    }
    
    //Helper function to check if there is already a valid connection
    private func checkSpotifyConnection() {
        SpotifyAuthManager.shared.getValidAccessToken { token in
            DispatchQueue.main.async {
                let connected = token != nil
                self.setSpotifyButtonState(connected: connected)
            }
        }
    }
}
