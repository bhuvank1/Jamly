//
//  GroupCreationViewController.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 11/10/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class GroupCreationViewController: UIViewController {

    @IBOutlet weak var groupNameTextField: UITextField!
    @IBOutlet weak var groupDescriptionTextField: UITextField!
    @IBOutlet weak var errorLabel: UILabel!
    
    private let db = Firestore.firestore()
    private var isLocked = false //variable to prevent duplicate creation
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        errorLabel.isHidden = true
    }
    
    
    @IBAction func createButtonClicked(_ sender: Any) {
        guard !isLocked else { return }
        guard let user = Auth.auth().currentUser else {
            showError("You must be signed in.")
            return
        }

        let name = (groupNameTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = (groupDescriptionTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty, !desc.isEmpty else {
            showError("Please enter a group name and description.")
            return
        }

        isLocked = true

        // Creator display name: prefer Auth.displayName, else email prefix, else fallback
        let authDisplay = (user.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let emailPrefix = (user.email ?? "").components(separatedBy: "@").first ?? ""
        let creatorDisplayName = authDisplay.isEmpty
            ? (emailPrefix.isEmpty ? "Unknown Display Name" : emailPrefix)
            : authDisplay

        let now = Timestamp(date: Date())

        let doc: [String: Any] = [
            "name": name,
            "description": desc,
            "creatorID": user.uid,
            "creatorDisplayName": creatorDisplayName,
            "members": [user.uid],   // only the creator for now
            "postsID": [],           // intentionally empty
        ]

        db.collection("groups").addDocument(data: doc) { [weak self] error in
            guard let self = self else { return }
            self.isLocked = false

            if let error = error {
                self.showError("Failed to create group: \(error.localizedDescription)")
                return
            }

            // Close screen: dismiss if presented modally, else pop
            if self.presentingViewController != nil && self.navigationController?.viewControllers.first == self {
                self.dismiss(animated: true)
            } else {
                self.navigationController?.popViewController(animated: true)
            }
        }
    }

    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }
}
