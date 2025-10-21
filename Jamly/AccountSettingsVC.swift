//
//  AccountSettingsVC.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 10/14/25.
//

import UIKit
import FirebaseFirestore

class AccountSettingsVC: UIViewController{
    
    @IBOutlet weak var nameField: UITextField!
    
    @IBOutlet weak var emailField: UITextField!
    
    @IBOutlet weak var mobileNumberField: UITextField!
    
    let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    @IBAction func saveButtonPressed(_ sender: Any) {
        // if at least one of the fields: name, email and number are not empty then add it to the database
        let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let email = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let mobileNumber = mobileNumberField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // Check if at least one field is not empty
        if !name.isEmpty || !email.isEmpty || !mobileNumber.isEmpty {
            let userData: [String: Any] = ["name": name, "email": email, "mobileNumber": mobileNumber]
            
            db.collection("userInfo").addDocument(data: userData) { (error) in
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
    
}
