//
//  SearchUsersViewController.swift
//  Jamly
//
//  Created by Rohan Pant on 11/5/25.
//
import UIKit
import FirebaseAuth
import FirebaseFirestore

class SearchViewController: UIViewController, UISearchBarDelegate {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var displayNameLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var mobileNumberLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!

    @IBOutlet weak var friendsButton: UIButton!   // “Friends (N)”
    @IBOutlet weak var addFriendButton: UIButton! // “Add Friend”

    private var foundUserID: String?   // Firestore docID (UID) of the searched user
    var user: User?                    // parsed user fields from Firestore

    override func viewDidLoad() {
        super.viewDidLoad()
        searchBar.delegate = self

        // Hide UI until a user is found
        [displayNameLabel, emailLabel, mobileNumberLabel, nameLabel].forEach { $0?.isHidden = true }
        friendsButton.isHidden = true
        addFriendButton.isHidden = true
        addFriendButton.isEnabled = false
    }

    // MARK: - Search
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text, !text.isEmpty else { return }
        searchUser(byDisplayName: text)
        searchBar.resignFirstResponder()
    }

    private func searchUser(byDisplayName displayName: String) {
        let db = Firestore.firestore()
        db.collection("userInfo")
            .whereField("displayName", isEqualTo: displayName)
            .limit(to: 1)
            .getDocuments { [weak self] snap, err in
                guard let self = self else { return }
                if let err = err { self.alert("Error", err.localizedDescription); return }
                guard let doc = snap?.documents.first else {
                    self.alert("Not found", "No user with that display name.")
                    self.addFriendButton.isHidden = true
                    self.friendsButton.isHidden = true
                    return
                }

                self.foundUserID = doc.documentID
                let d = doc.data()
                let friends = d["friends"] as? [String] ?? []
                self.user = User(
                    displayName: d["displayName"] as? String ?? "",
                    email:       d["email"] as? String ?? "",
                    mobileNumber:d["mobileNumber"] as? String ?? "",
                    name:        d["name"] as? String ?? "",
                    friends:     friends
                )
                self.updateProfileUI()
            }
    }

    private func updateProfileUI() {
        guard let u = user else { return }
        displayNameLabel.text     = "Display Name: \(u.displayName)"
        emailLabel.text           = "Email: \(u.email)"
        mobileNumberLabel.text    = "Mobile: \(u.mobileNumber)"
        nameLabel.text            = "Name: \(u.name)"
        friendsButton.setTitle("Friends (\(u.friends.count))", for: .normal)

        [displayNameLabel, emailLabel, mobileNumberLabel, nameLabel].forEach { $0?.isHidden = false }
        friendsButton.isHidden = false
        addFriendButton.isHidden = false
        addFriendButton.isEnabled = true
    }

    // MARK: - Add Friend
    @IBAction func addFriendButtonTapped(_ sender: UIButton) {
        guard let currentUID = Auth.auth().currentUser?.uid else {
            alert("Not signed in", "Please sign in first.")
            return
        }
        guard let friendUID = foundUserID else { return }
        if currentUID == friendUID {
            alert("Oops", "You can’t add yourself.")
            return
        }

        let db = Firestore.firestore()
        let myDoc = db.collection("userInfo").document(currentUID)
        let friendDoc = db.collection("userInfo").document(friendUID)

        // Add friend to my list (arrayUnion prevents duplicates)
        myDoc.updateData(["friends": FieldValue.arrayUnion([friendUID])]) { [weak self] err in
            guard let self = self else { return }
            if let err = err { self.alert("Error", err.localizedDescription); return }

            // OPTIONAL: make it mutual (comment out if you want one-way requests)
            friendDoc.updateData(["friends": FieldValue.arrayUnion([currentUID])]) { _ in }

            self.addFriendButton.setTitle("Added", for: .normal)
            self.addFriendButton.isEnabled = false

            // Update local count
            if var u = self.user, !u.friends.contains(friendUID) {
                u.friends.append(friendUID)
                self.user = u
                self.friendsButton.setTitle("Friends (\(u.friends.count))", for: .normal)
            }
        }
    }

    // MARK: - Friends list segue
    @IBAction func friendsButtonTapped(_ sender: UIButton) {
        guard let ids = user?.friends, !ids.isEmpty else {
            alert("No friends", "This user has no friends yet.")
            return
        }
        performSegue(withIdentifier: "showFriendsSegue", sender: ids)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showFriendsSegue",
           let dest = segue.destination as? UserFriendsViewController,
           let friendIDs = sender as? [String] {
            dest.friendIDs = friendIDs
        }
    }

    // MARK: - Helpers
    private func alert(_ title: String, _ msg: String) {
        let ac = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
}
