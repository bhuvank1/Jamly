//
//  ViewController.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 10/13/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    
    @IBOutlet weak var feedTableView: UITableView!
    private var posts: [Post] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        feedTableView.dataSource = self
        feedTableView.delegate = self
        fetchSocialFeed()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        checkSpotifyConnection()
    }
    
    func fetchSocialFeed() {
        guard let currentUID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("userInfo").document(currentUID).getDocument { querySnapshot, error in
            if let error = error {
                print("could not fetch user")
                return
            }
            
            guard let data = querySnapshot?.data(),
                  let friendIDs = data["friends"] as? [String], !friendIDs.isEmpty else {
                print("No friends found")
                return
            }
            
            // fetch post for friends if array is not empty
            self.fetchPostsForUserID(for: friendIDs)
            
        }
    }
    
    func fetchPostsForUserID(for userIDs: [String]) {
        let db = Firestore.firestore()
        self.posts.removeAll()
        
        db.collection("posts").whereField("userID", in: userIDs).getDocuments { querySnapshot, error in
            if let error = error {
                print("error in fetching posts for feed")
            } else {
                for document in querySnapshot!.documents {
                    let data = document.data()
                    let rating = data["rating"] as? Int ?? (data["rating"] as? NSNumber)?.intValue ?? 0
                    let caption = data["caption"] as? String ?? ""
                    let likes = data["likes"] as? [String] ?? []
                    let musicName = data["musicName"] as? String ?? ""
                    
                    let commentDicts = data["comments"] as? [[String: Any]] ?? []
                    var comments: [Comment] = []
                        for dict in commentDicts {
                           if let userID = dict["userID"] as? String,
                               let commentText = dict["commentText"] as? String {
                               let comment = Comment(userID: userID, commentText: commentText)
                               comments.append(comment)
                            }
                        }
                        
                    let newPost = Post(userID: uid, postID: document.documentID, rating: rating, likes: likes, caption: caption,
                                           comments: comments,musicName: musicName)
                        
                        self.postDocs.append(newPost)
                    
                }
            
        }
    }

    func displayPopup() {
        let controller = UIAlertController(
            title: "Spotify",
            message: "Connect to your Spotify account to continue",
            preferredStyle: .alert)
        
        let connectAction = UIAlertAction(title: "Connect to Spotify", style: .default, handler: alertHander(alert:))
        controller.addAction(connectAction)
        controller.preferredAction = connectAction
        
        present(controller, animated: true)
    }
    
    func alertHander(alert:UIAlertAction) {
        SpotifyAuthManager.shared.signIn {
            success in DispatchQueue.main.async {
                if success {
                    let alert = UIAlertController(title: "Connected!", message: "You can now use Spotify features.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                    print("WE CONNECTED YAY")
                } else {
                    let alert = UIAlertController(title: "Login Failed", message: "Please try again.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                    self.displayPopup()
                }
            }
        }
    }
    
    //Helper function to check if there is already a valid connection
    private func checkSpotifyConnection() {
        SpotifyAuthManager.shared.getValidAccessToken { token in
            DispatchQueue.main.async {
                let connected = token != nil
                if (connected == false) {
                    self.displayPopup()
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        posts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = feedTableView.dequeueReusableCell(withIdentifier: "TextCell", for: indexPath) as? PostTableViewCell else {
            fatalError("Could not deque post cell")
        }
        
        let post = posts[indexPath.row]
        cell.postImageView.image = UIImage(named: "Jamly_LogoPDF")
        cell.usernameLabel.text = "monaaaaa.mitruhhhhh"
        return cell
    }
    
}

