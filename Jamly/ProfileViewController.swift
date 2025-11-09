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

    // Profile UI
    @IBOutlet weak var usernameLabel: UILabel!       // Shows user's name
    @IBOutlet weak var displayPostTable: UITableView!
    @IBOutlet weak var userImage: UIImageView!
    @IBOutlet weak var friendsButton: UIButton!      // “Friends (N)”

    private var postDocs: [Post] = []
    private var listener: ListenerRegistration?
    private var userFriendIDs: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        displayPostTable.dataSource = self
        displayPostTable.delegate = self
        displayPostTable.isScrollEnabled = true
        displayPostTable.rowHeight = UITableView.automaticDimension
        displayPostTable.estimatedRowHeight = 72

        friendsButton.isEnabled = false
        friendsButton.setTitle("Friends (0)", for: .normal)

        fetchUserInfo()      // 🔹 NEW: get username from Firestore
        fetchMyFriends()
        startListeningForPosts()
    }

    deinit { listener?.remove() }

    // MARK: - Fetch user info (for usernameLabel)
    private func fetchUserInfo() {
        let db = Firestore.firestore()
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("userInfo").document(uid).getDocument { [weak self] doc, err in
            guard let self = self else { return }
            if let err = err {
                print("Error fetching user info: \(err)")
                return
            }
            guard let data = doc?.data() else { return }

            // Use name or displayName field
            let displayName = data["name"] as? String ?? data["displayName"] as? String ?? "(Unknown User)"
            DispatchQueue.main.async {
                self.usernameLabel.text = displayName
            }
        }
    }

    // MARK: - Firestore: My friends (from userInfo/{uid}.friends)
    private func fetchMyFriends() {
        let db = Firestore.firestore()
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("userInfo").document(uid).getDocument { [weak self] doc, err in
            guard let self = self else { return }
            if let err = err {
                print("Error fetching friends: \(err)")
                return
            }
            let friends = doc?.data()?["friends"] as? [String] ?? []
            self.userFriendIDs = friends
            DispatchQueue.main.async {
                self.friendsButton.setTitle("Friends (\(friends.count))", for: .normal)
                self.friendsButton.isEnabled = true
            }
        }
    }

    // MARK: - Firestore: Posts
    private func startListeningForPosts() {
        let db = Firestore.firestore()
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("posts").whereField("userID", isEqualTo: uid).getDocuments { [weak self] (querySnapshot, err) in
            guard let self = self else { return }
            if let err = err {
                print("Error getting posts: \(err)")
                return
            }
            self.postDocs.removeAll()
            querySnapshot?.documents.forEach { document in
                let data = document.data()
                if let rating = (data["rating"] as? Int) ?? (data["rating"] as? NSNumber)?.intValue,
                   let caption = data["caption"] as? String,
                   let likes = data["likes"] as? [String],
                   let musicName = data["musicName"] as? String,
                   let commentDicts = data["comments"] as? [[String: Any]],
                   let uid = Auth.auth().currentUser?.uid {

                    var comments: [Comment] = []
                    for dict in commentDicts {
                        if let userID = dict["userID"] as? String,
                           let commentText = dict["commentText"] as? String {
                            comments.append(Comment(userID: userID, commentText: commentText))
                        }
                    }

                    let newPost = Post(userID: uid,
                                       postID: document.documentID,
                                       rating: rating,
                                       likes: likes,
                                       caption: caption,
                                       comments: comments,
                                       musicName: musicName)

                    self.postDocs.append(newPost)
                }
            }
            DispatchQueue.main.async {
                self.displayPostTable.reloadData()
            }
        }
    }

    // MARK: - Friends button
    @IBAction func friendsButtonTapped(_ sender: UIButton) {
        guard !userFriendIDs.isEmpty else {
            alert("No friends", "You haven't added any friends yet.")
            return
        }
        guard let vc = storyboard?.instantiateViewController(withIdentifier: "FriendsViewControllerID") as? UserFriendsViewController else {
            assertionFailure("FriendsViewControllerID not found in storyboard")
            return
        }
        vc.friendIDs = userFriendIDs
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Table
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        postDocs.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = displayPostTable.dequeueReusableCell(withIdentifier: "postCell", for: indexPath) as? PostThumbnailTableViewCell else {
            fatalError("Could not dequeue post cell")
        }

        let postData = postDocs[indexPath.row]
        cell.songName.text = postData.musicName
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

    // MARK: - Helpers
    private func alert(_ title: String, _ msg: String) {
        let ac = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
}
