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

protocol ChangeLikesSocialFeed {
    func changeLikes(for post: Post, cell: PostTableViewCell)
}

protocol ChangeCommentsSocialFeed {
    func changeComments(postID: String, newComment: Comment)
}

protocol ShowPopup {
    func makePopup(popupTitle:String, popupMessage:String)
}

protocol ShowMutualGroups {
    func didTapMutualGroups(for post: Post)
}


class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, ShowLikesComments, ChangeLikesSocialFeed, ChangeCommentsSocialFeed, ShowPopup,
                      ShowMutualGroups {
    
    @IBOutlet weak var feedTableView: UITableView!
    private var posts: [Post] = []
    var mutualGroups: [Group] = []
    var mutualGroupCache: [String: Bool] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        feedTableView.dataSource = self
        feedTableView.delegate = self
        
        feedTableView.backgroundColor = .clear
        view.backgroundColor = UIColor(red: 1.0, green: 0.9372549019607843, blue: 0.8980392156862745, alpha: 1.0)
        self.title = "Jamly 🍓"
        
        //fetchSocialFeed()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        fetchSocialFeed()
        checkSpotifyConnection()
        
        // fixing white top nav bar issue
        guard let navBar = navigationController?.navigationBar else { return }
        navBar.barTintColor = UIColor(red: 1.0, green: 0.9372549019607843, blue: 0.8980392156862745, alpha: 1.0)
        navBar.titleTextAttributes = [.font: UIFont(name: "Poppins-SemiBold", size: 20)!]
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
                   cell.likeHeartButton.setImage(UIImage(systemName: "heart.fill"), for: .normal)
                   cell.likeHeartButton.tintColor = UIColor(red: 0.23921568627450981, green: 0.12156862745098039, blue: 0.1568627450980392, alpha: 1.0)
                   } else {
                    cell.likeHeartButton.setImage(UIImage(systemName: "heart"), for: .normal)
                    cell.likeHeartButton.tintColor = UIColor(red: 0.23921568627450981, green: 0.12156862745098039, blue: 0.1568627450980392, alpha: 1.0)
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
        // clearing cache
        self.mutualGroupCache.removeAll()
        
        db.collection("posts").whereField("userID", in: userIDs).getDocuments { querySnapshot, error in
            if let error = error {
                print(error.localizedDescription)
            } else {
                for document in querySnapshot!.documents {
                    let data = document.data()
                    if let userID = data["userID"] as? String,
                       let displayName = data["displayName"] as? String,
                       let rating = data["rating"] as? Int ?? (data["rating"] as? Int),
                       let caption = data["caption"] as? String {
                        
                        let likes = data["likes"] as? [String] ?? []
                         
                        
                        let commentDicts = data["comments"] as? [[String: Any]] ?? []
                        var comments: [Comment] = []
                        for dict in commentDicts {
                            if let userID = dict["userID"] as? String,
                               let commentText = dict["commentText"] as? String {
                                let comment = Comment(userID: userID, commentText: commentText)
                                comments.append(comment)
                            }
                        }
                        
                        let trackData = data["trackObject"] as? [String: Any]
                                    let track = Track(
                                        id: trackData?["id"] as? String ?? "",
                                        name: trackData?["name"] as? String ?? "Unknown Song",
                                        artists: trackData?["artists"] as? String ?? "Unknown Artist",
                                        duration_ms: trackData?["duration_ms"] as? Int ?? 0,
                                        albumArt: trackData?["albumArt"] as? String,
                                        image: nil
                                    )
                        
                        let newPost = Post(userID: userID, displayName: displayName, postID: document.documentID, rating: rating, likes: likes, caption: caption,
                                           comments: comments, trackObject: track)
                        self.posts.append(newPost)
                    }
                    
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
    
    func didTapMutualGroups(for post: Post) {
    self.performSegue(withIdentifier: "showMutualGroupsSegue", sender: post)
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
        print(posts.count)
        return posts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = feedTableView.dequeueReusableCell(withIdentifier: "TextCell", for: indexPath) as? PostTableViewCell else {
            fatalError("Could not deque post cell")
        }
        
        let post = posts[indexPath.row]
        cell.usernameLabel.text = post.displayName
        cell.commentsButton.setTitle(String(post.comments.count), for: .normal)
        cell.likesButton.setTitle(String(post.likes.count), for: .normal)
        cell.ratingLabel.text = "\(post.rating)/5"
        cell.captionText.text = post.caption
        cell.songNameLabel.text = post.trackObject.name
        cell.artistNameLabel.text = post.trackObject.artists
        
        // image
        if let urlStr = post.trackObject.albumArt, let url = URL(string: urlStr) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data, let img = UIImage(data: data) else { return }
                DispatchQueue.main.async {
                    // Only set the image if the cell is still displaying this row
                    if let visibleCell = tableView.cellForRow(at: indexPath) as? PostTableViewCell {
                        visibleCell.postImageView.image = img
                    }
                }
            }.resume()
        }
        
        // delegate
        cell.delegate = self
        cell.post = post
        
        // render mututal groups button on each cell
        if let hasMutual = mutualGroupCache[post.userID] {
            cell.mutualGroupsButton.isHidden = !hasMutual
        } else {
            cell.mutualGroupsButton.isHidden = true
            checkMutualGroups(for: post) { hasMutual in
                self.mutualGroupCache[post.userID] = hasMutual
                DispatchQueue.main.async {
                    if let currentIndex = tableView.indexPath(for: cell),
                       self.posts[currentIndex.row].userID == post.userID {
                        cell.mutualGroupsButton.isHidden = !hasMutual
                    }
                }
            }
        }
        
        // likes button image
        guard let currentUID = Auth.auth().currentUser?.uid else { return cell }
        if post.likes.contains(currentUID) {
            cell.likeHeartButton.setImage(UIImage(systemName: "heart.fill"), for: .normal)
            cell.likeHeartButton.tintColor = UIColor(red: 0.23921568627450981, green: 0.12156862745098039, blue: 0.1568627450980392, alpha: 1.0)
        } else {
            cell.likeHeartButton.setImage(UIImage(systemName: "heart"), for: .normal)
            cell.likeHeartButton.tintColor = UIColor(red: 0.23921568627450981, green: 0.12156862745098039, blue: 0.1568627450980392, alpha: 1.0)
        }
        return cell
    }
    
    func checkMutualGroups(for post: Post, completion: @escaping (Bool) -> Void) {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let db = Firestore.firestore()
        self.mutualGroups.removeAll()
        
        // fetch mututal groups
        db.collection("groups").whereField("members", arrayContains: currentUserID).getDocuments() { querySnapshot, err in
            if let err = err {
                print("Error in fetching documents: \(err.localizedDescription)")
                completion(false)
                return
            }
            
            guard let docs = querySnapshot?.documents else {
                completion(false)
                return
            }
            
            let hasMutual = docs.contains { doc in
                guard let group = Group(doc: doc) else { return false }
                return group.members.contains(post.userID)
            }
            
            completion(hasMutual)
            
        }
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
        } else if segue.identifier == "showMutualGroupsSegue",
                  let destVC = segue.destination as? MutualGroupsViewController {
            destVC.post = post
        }
    }
    
    func makePopup(popupTitle:String, popupMessage:String) {
        let controller = UIAlertController(
            title: popupTitle,
            message: popupMessage,
            preferredStyle: .alert)
        
        controller.addAction(UIAlertAction(title: "OK", style: .default))
        present(controller,animated:true)
    }
}

