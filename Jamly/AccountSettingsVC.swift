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
    
    @IBOutlet weak var mobileNumberField: UITextField!
    
    @IBOutlet weak var saveChangesButton: UIButton!
    @IBOutlet weak var nameText: UILabel!
    @IBOutlet weak var emailText: UILabel!
    
    @IBOutlet weak var mobileLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(hex: "#FFEFE5")
        
        if let font = UIFont(name: "Poppins-SemiBold", size: 16) {
            nameText.font = font
            mobileLabel.font = font
            nameLabel.font = font
        }
        
        if let font = UIFont(name: "Poppins-Regular", size: 12) {
            emailText.font = font
        }
        
        if let font = UIFont(name: "Poppins-Regular", size: 14) {
            nameField.font = font
            mobileNumberField.font = font
        }
        
        var config = UIButton.Configuration.filled()
        config.title = "Save Changes"
        config.baseBackgroundColor = UIColor(hex: "#FFC1CC")
        config.baseForegroundColor = UIColor(hex: "#3D1F28")
        config.cornerStyle = .medium
        config.titleAlignment = .center
        saveChangesButton.configuration = config
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        fetchUserInfo()
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
                
                DispatchQueue.main.async {
                    self.nameText.text = name
                    self.emailText.text = user.email
                }
            }
        }
    }
    
    @IBAction func saveButtonPressed(_ sender: Any) {
        // if at least one of the fields: name, email and number are not empty then add it to the database
        let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let mobileNumber = mobileNumberField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // Check if at least one field is not empty
        if !name.isEmpty || !mobileNumber.isEmpty {
            // get user id to associate a user to their user info
            guard let user = Auth.auth().currentUser else {
                print("No user is currently signed in.")
                return
            }
            
            let uid = user.uid
            
            var updates: [String: Any] = [:]
            if !name.isEmpty { updates["name"] = name }
            if !mobileNumber.isEmpty { updates["mobileNumber"] = mobileNumber }
            
            db.collection("userInfo").document(uid).updateData(updates) { (error) in
                if let error = error {
                    print("Error adding document: \(error)")
                } else {
                    print("Document successfully added")
                }
            }
        } else {
            print("All fields are empty. Nothing to save.")
        }
    }
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        self.dismiss(animated: true)
    }
    
}
