//
//  ProfileViewController.swift
//  Jamly
//
//  Created by Rohan Pant on 10/17/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class ProfileViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // Other profile UI
    @IBOutlet weak var followersCountButton: UIButton!
    @IBOutlet weak var followingCountButton: UIButton!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var displayPostTable: UITableView!
    @IBOutlet weak var userImage: UIImageView!
    
    
    
    private var postDocs: [Post] = []
    private var listener: ListenerRegistration?
    
    
    private let showOnlyCurrentUser = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        displayPostTable.dataSource = self
        displayPostTable.delegate = self
        displayPostTable.isScrollEnabled = true
        displayPostTable.rowHeight = UITableView.automaticDimension
        displayPostTable.estimatedRowHeight = 72
        
        startListeningForPosts()
    }
    
    deinit { listener?.remove() }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    private func startListeningForPosts() {
        let db = Firestore.firestore()
        guard let uid = Auth.auth().currentUser?.uid else { return }
        self.postDocs.removeAll()
        
        db.collection("posts").whereField("userID", isEqualTo: uid).getDocuments {
            (querySnapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                for document in querySnapshot!.documents {
                    let data = document.data()
                    if let rating = data["rating"] as? Int ?? (data["rating"] as? NSNumber)?.intValue,
                       let caption = data["caption"] as? String,
                       let likes = data["likes"] as? [String],
                       let trackObject = data["trackObject"] as? Track,
                       let commentDicts = data["comments"] as? [[String: Any]] {
                        
                        var comments: [Comment] = []
                        for dict in commentDicts {
                           if let userID = dict["userID"] as? String,
                               let commentText = dict["commentText"] as? String {
                               let comment = Comment(userID: userID, commentText: commentText)
                               comments.append(comment)
                            }
                        }
                        
                        let newPost = Post(userID: uid, displayName: user.displayName ?? "Username", postID: document.documentID, rating: rating, likes: likes, caption: caption,
                                           comments: comments,trackObject: trackObject.toDictionary())
                        
                        self.postDocs.append(newPost)
                    
                }
                print(self.postDocs.count)
                self.displayPostTable.reloadData()
            }
        }
    }
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            //print(postDocs.count)
            return postDocs.count
        }
        
        func tableView(_ tableView: UITableView,
                       cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            
            guard let cell = displayPostTable.dequeueReusableCell(withIdentifier: "postCell", for: indexPath) as? PostThumbnailTableViewCell else {
                fatalError("Could not deque timer cell")
            }
            
            let postData = postDocs[indexPath.row]
            
            if let trackDict = postData.trackObject as? [String: Any],
               let trackName = trackDict["name"] as? String {
                cell.songName.text = trackName
            } else {
                cell.songName.text = "No song"
            }
            cell.songRating.text = String(postData.rating)
            
            return cell
        }
        
        
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            
            displayPostTable.deselectRow(at: indexPath, animated: true)
        }
    
        override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            if segue.identifier == "postDetailSegue",
               let postIndex = displayPostTable.indexPathForSelectedRow?.row,
               let destVC = segue.destination as? PostDetailViewController {
                destVC.post = postDocs[postIndex]
            }
        }
    
    }

