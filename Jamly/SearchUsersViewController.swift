//
//  SearchUsersViewController.swift
//  Jamly
//
//  Created by Rohan Pant on 11/5/25.
//

import UIKit
import FirebaseFirestore

class SearchUsersViewController: UIViewController, UISearchBarDelegate {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var displayNameLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var mobileNumberLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var friendsButton: UIButton!  
   
    var user: User?  // Store the user data
   
    override func viewDidLoad() {
        super.viewDidLoad()
       
        searchBar.delegate = self
       
        // Initially, hide the user info labels until a user is found
        displayNameLabel.isHidden = true
        emailLabel.isHidden = true
        mobileNumberLabel.isHidden = true
        nameLabel.isHidden = true
        friendsButton.isHidden = true  // Hide the button until the user is found
    }
   
    // This method will be called when the user taps the return key on the search bar
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        // Get the search text (displayName)
        guard let searchText = searchBar.text, !searchText.isEmpty else {
            return
        }
       
        // Call Firestore query method to search for a user by their displayName
        searchUser(byDisplayName: searchText)
       
        // Dismiss the keyboard after search
        searchBar.resignFirstResponder()
    }
   
    // Function to search for a user by their displayName
    func searchUser(byDisplayName displayName: String) {
        let db = Firestore.firestore()
       
        // Query Firestore userInfo collection to find a user by exact displayName
        db.collection("userInfo")
            .whereField("displayName", isEqualTo: displayName)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error searching user: \(error.localizedDescription)")
                    self.showPopup(title: "Error", message: "User not found.")
                    return
                }
               
                // Check if any matching user is found
                if let documents = querySnapshot?.documents, !documents.isEmpty {
                    // Assuming one user with the exact displayName exists
                    let userData = documents.first?.data()
                    if let user = self.convertToUser(data: userData) {
                        self.user = user
                        self.displayUserInfo(user)
                    } else {
                        self.showPopup(title: "Error", message: "Error parsing user data.")
                    }
                } else {
                    self.showPopup(title: "User Not Found", message: "No user with this display name.")
                }
            }
    }
   
    // Convert Firestore data to User object (or just extract necessary data)
    func convertToUser(data: [String: Any]?) -> User? {
        guard let data = data else { return nil }
       
        // Extract the necessary user info
        let displayName = data["displayName"] as? String ?? ""
        let email = data["email"] as? String ?? ""
        let mobileNumber = data["mobileNumber"] as? String ?? ""
        let name = data["name"] as? String ?? ""
        let friends = data["friends"] as? [String] ?? []  // Fetch friends array
       
        return User(displayName: displayName, email: email, mobileNumber: mobileNumber, name: name, friends: friends)
    }

    // Display user info in the UI (after finding a match)
    func displayUserInfo(_ user: User) {
        displayNameLabel.text = "Display Name: \(user.displayName)"
        emailLabel.text = "Email: \(user.email)"
        mobileNumberLabel.text = "Mobile Number: \(user.mobileNumber)"
        nameLabel.text = "Name: \(user.name)"
        friendsButton.setTitle("Friends (\(user.friends.count))", for: .normal)  // Set the friends button title
       
        // Show the labels and the button with the user information
        displayNameLabel.isHidden = false
        emailLabel.isHidden = false
        mobileNumberLabel.isHidden = false
        nameLabel.isHidden = false
        friendsButton.isHidden = false  // Show the button with the count of friends
    }
   
    // Helper function to show a popup with a title and message
    func showPopup(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }

    // Action when the "Friends" button is tapped
    @IBAction func friendsButtonTapped(_ sender: UIButton) {
        if let friends = user?.friends {
            performSegue(withIdentifier: "showFriendsSegue", sender: friends)
        }
    }
   
    // Prepare the data to pass to FriendsViewController
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showFriendsSegue" {
            if let friendsVC = segue.destination as? UserFriendsViewController,
               let friends = sender as? [String] {
                // Fetch the user info for each friend and pass it to the FriendsViewController
                var friendsList: [User] = []
               
                // Query Firestore to get the details of each friend
                let db = Firestore.firestore()
                for friendID in friends {
                    db.collection("userInfo").document(friendID).getDocument { (document, error) in
                        if let error = error {
                            print("Error fetching friend data: \(error.localizedDescription)")
                            return
                        }
                       
                        if let document = document, document.exists {
                            let friendData = document.data()
                            if let friend = self.convertToUser(data: friendData) {
                                friendsList.append(friend)
                            }
                        }
                    }
                }
               
                // Pass the list of friends to the FriendsViewController
                friendsVC.updateFriendsList(friends: friendsList)
            }
        }
    }
}
