//
//  SearchUsersViewController.swift
//  Jamly
//
//  Created by Rohan Pant on 11/5/25.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth

class SearchUsersViewController: UIViewController, UISearchBarDelegate, UITableViewDataSource {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var profilePictureImageView: UIImageView!
    @IBOutlet weak var friendsLabel: UILabel!  // Show number of friends
    @IBOutlet weak var tableView: UITableView!  // UITableView to display posts
   
    var posts: [Post] = []  // Array to store posts for the user
   
    override func viewDidLoad() {
        super.viewDidLoad()
       
        searchBar.delegate = self
       
        // Initially, hide the labels and image view until a user is found
        usernameLabel.isHidden = true
        emailLabel.isHidden = true
        profilePictureImageView.isHidden = true
        friendsLabel.isHidden = true
        tableView.isHidden = true
    }

    // This method will be called when the user taps the return key on the search bar
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        // Get the search text (username)
        guard let searchText = searchBar.text, !searchText.isEmpty else {
            return
        }
       
        // Call Firestore query method to search for a user by their username
        searchUser(byUsername: searchText)
       
        // Dismiss the keyboard after search
        searchBar.resignFirstResponder()
    }
   
    func searchUser(byUsername username: String) {
        let db = Firestore.firestore()
       
        // Query Firestore users collection to find user by exact username
        db.collection("users")
            .whereField("username", isEqualTo: username)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error searching user: \(error.localizedDescription)")
                    self.showPopup(title: "Error", message: "User not found.")
                    return
                }
               
                // Check if any matching user is found
                if let documents = querySnapshot?.documents, !documents.isEmpty {
                    // Assuming one user with the exact username exists
                    let userData = documents.first?.data()
                    if let user = self.convertToUser(data: userData) {
                        self.displayUserInfo(user)
                        self.fetchUserPosts(uid: user.uid)
                    } else {
                        self.showPopup(title: "Error", message: "Error parsing user data.")
                    }
                } else {
                    self.showPopup(title: "User Not Found", message: "No user with this username.")
                }
            }
    }
   
    // Convert Firestore data to User object (or just extract necessary data)
    func convertToUser(data: [String: Any]?) -> User? {
        guard let data = data else { return nil }
       
        // Extract the necessary user info
        let username = data["username"] as? String ?? ""
        let email = data["email"] as? String ?? ""
        let profilePictureURL = data["profilePictureURL"] as? String ?? ""
        let friends = data["friends"] as? [String] ?? []
       
        return User(uid: "", email: email, name: "", username: username, profilePictureURL: profilePictureURL, posts: [], friends: friends)
    }

    // Display user info in the UI (after finding a match)
    func displayUserInfo(_ user: User) {
        usernameLabel.text = "Username: \(user.username)"
        emailLabel.text = "Email: \(user.email)"
        friendsLabel.text = "Friends: \(user.friends.count)"  // Show number of friends
       
        // Try to load the profile picture if the URL is available
        if let url = URL(string: user.profilePictureURL!), !user.profilePictureURL!.isEmpty {
            loadImage(from: url)
        } else {
            profilePictureImageView.image = UIImage(named: "default_profile_picture") 
        }
       
        // Show the labels and image view
        usernameLabel.isHidden = false
        emailLabel.isHidden = false
        profilePictureImageView.isHidden = false
        friendsLabel.isHidden = false
        tableView.isHidden = false  // Show the table view with posts
    }
   
    // Helper function to load image from URL asynchronously
    func loadImage(from url: URL) {
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let error = error {
                print("Error loading image: \(error.localizedDescription)")
                return
            }
           
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.profilePictureImageView.image = image
                }
            }
        }
        task.resume()
    }
   
    // Fetch posts from Firestore for the user
    func fetchUserPosts(uid: String) {
        let db = Firestore.firestore()
       
        // Query Firestore to fetch posts by this user
        db.collection("posts")
            .whereField("userID", isEqualTo: uid)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error fetching posts: \(error.localizedDescription)")
                    return
                }
               
                // Parse the posts data
                if let documents = querySnapshot?.documents {
                    self.posts = documents.compactMap { doc in
                        let data = doc.data()
                        return Post.fromFirestore(data: data)
                    }
                   
                    // Reload the table view to display posts
                    self.tableView.reloadData()
                }
            }
    }
   
    // UITableView DataSource Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return posts.count  // Number of posts
    }
   
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PostCell", for: indexPath)
       
        let post = posts[indexPath.row]
       
        // Configure the cell with post data
        cell.textLabel?.text = post.caption
        cell.detailTextLabel?.text = "Likes: \(post.likes)"
       
        return cell
    }
   
    // Helper function to show a popup with a title and message
    func showPopup(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }
}

