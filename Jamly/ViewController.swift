//
//  ViewController.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 10/13/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

protocol ShowLikesComments {
    func didTapLikesButton(for post: Post)
    func didTapCommentsButton(for post: Post)
}

protocol ChangeLikes {
    func changeLikes(for post: Post, cell: PostTableViewCell)
}

protocol ChangeComments {
    func changeComments(postID: String, newComment: Comment)
}

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, ShowLikesComments, ChangeLikes, ChangeComments {
    
    
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
    
    func changeLikes(for post: Post, cell: PostTableViewCell) {
        print("HERE IN CHANGE LIKES")
        guard let currentUID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        let postRef = db.collection("posts").document(post.postID)
        var updatedLikes = post.likes
        
        if let index = updatedLikes.firstIndex(of: currentUID) {
                updatedLikes.remove(at: index)
            } else {
                updatedLikes.append(currentUID)
            }
        
        postRef.updateData(["likes": updatedLikes]) { error in
            if let error = error {
                print("Error updating likes: \(error.localizedDescription)")
                return
            }
            post.likes = updatedLikes
            
            DispatchQueue.main.async {
                 self.feedTableView.reloadData()
                 cell.likesButton.setTitle(String(post.likes.count), for: .normal)
                
                if post.likes.contains(currentUID) {
                   cell.likesButton.setImage(UIImage(systemName: "heart.fill"), for: .normal)
                   } else {
                    cell.likesButton.setImage(UIImage(systemName: "heart"), for: .normal)
                   }
            }
            
        }
    }
    
    func changeComments(postID: String, newComment: Comment) {
        guard let index = posts.firstIndex(where: { $0.postID == postID }) else { return }
        let post = posts[index]
        post.comments.append(newComment)
        if let cell = feedTableView.cellForRow(at: IndexPath(row: index, section: 0)) as? PostTableViewCell {
                    cell.commentsButton.setTitle(String(post.comments.count), for: .normal)
                }
    }
    
    func fetchSocialFeed() {
        guard let currentUID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("userInfo").document(currentUID).getDocument { querySnapshot, error in
            if let error = error {
                print(error.localizedDescription)
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
                print(error.localizedDescription)
            } else {
                for document in querySnapshot!.documents {
                    let data = document.data()
                    let userID = data["userID"] as? String ?? ""
                    let displayName = data["displayName"] as? String ?? "Unknown"
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
                    
                    let newPost = Post(userID: userID, postID: document.documentID, rating: rating, likes: likes, caption: caption,
                                       comments: comments,musicName: musicName, displayName: displayName)
                    
                    self.posts.append(newPost)
                    
                }
                self.feedTableView.reloadData()
            }
        }
    }
    
    func didTapLikesButton(for post: Post) {
        performSegue(withIdentifier: "likesMainSegue", sender: post)
    }
    
    func didTapCommentsButton(for post: Post) {
        performSegue(withIdentifier: "commentsMainSegue", sender: post)
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
        return posts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = feedTableView.dequeueReusableCell(withIdentifier: "TextCell", for: indexPath) as? PostTableViewCell else {
            fatalError("Could not deque post cell")
        }
        
        let post = posts[indexPath.row]
        cell.postImageView.image = UIImage(named: "Jamly_LogoPDF")
        cell.usernameLabel.text = post.displayName
        cell.commentsButton.setTitle(String(post.comments.count), for: .normal)
        cell.likesButton.setTitle(String(post.likes.count), for: .normal)
        cell.ratingLabel.text = "\(post.rating)/5"
        cell.captionText.text = post.caption
        
        // delegate
        cell.delegate = self
        cell.post = post
        
        // likes button image
        guard let currentUID = Auth.auth().currentUser?.uid else { return cell }
        if post.likes.contains(currentUID) {
            cell.likesButton.setImage(UIImage(systemName: "heart.fill"), for: .normal)
        } else {
            cell.likesButton.setImage(UIImage(systemName: "heart"), for: .normal)
        }
        return cell
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let post = sender as? Post else { return }
        
        if segue.identifier == "likesMainSegue",
           let destVC = segue.destination as? LikeViewController {
            destVC.likes = post.likes
        } else if segue.identifier == "commentsMainSegue",
                  let destVC = segue.destination as? CommentsViewController {
            destVC.comments = post.comments
            destVC.postID = post.postID
            destVC.delegate = self
        }
                    
    }
    
}

