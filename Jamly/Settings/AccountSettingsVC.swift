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
    
    @IBOutlet weak var groupsNumText: UILabel!
    @IBOutlet weak var postsNumText: UILabel!
    @IBOutlet weak var nameText: UILabel!
    @IBOutlet weak var emailText: UILabel!
    

    @IBOutlet weak var groupsNumLabel: UILabel!
    @IBOutlet weak var postCreatedLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(hex: "#FFEFE5")
        
        if let font = UIFont(name: "Poppins-SemiBold", size: 16) {
            groupsNumLabel.font = font
            postCreatedLabel.font = font
            emailLabel.font = font
            nameLabel.font = font
        }
        
        if let font = UIFont(name: "Poppins-Regular", size: 15) {
            emailText.font = font
            nameText.font = font
            groupsNumText.font = font
            postsNumText.font = font
        }
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
                let name = data?["displayName"] as? String ?? "your display name"
                
                DispatchQueue.main.async {
                    self.nameText.text = name
                    self.emailText.text = user.email
                }
            }
        }
        
        // retrieve number of posts
        db.collection("posts").whereField("userID", isEqualTo: uid).getDocuments { snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.postsNumText.text = "0"
                }
                return
            }
            
            let count = snapshot?.documents.count ?? 0
            DispatchQueue.main.async {
                self.postsNumText.text = "\(count)"
            }
        }
        
        // retrieve number of groups
        db.collection("groups").whereField("members", arrayContains: uid).getDocuments { snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.groupsNumText.text = "0"
                }
                return
            }
            
            let count = snapshot?.documents.count ?? 0
            DispatchQueue.main.async {
                self.groupsNumText.text = "\(count)"
            }
        }
    }
    
}
