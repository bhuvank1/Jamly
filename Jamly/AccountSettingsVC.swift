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
        if !nameField.text!.isEmpty && !emailField.text!.isEmpty && !mobileNumberField.text!.isEmpty {
            
        }
    }
    
}
