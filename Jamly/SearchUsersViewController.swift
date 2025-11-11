//
//  SearchViewController.swift
//  Jamly
//
//  Created by Rohan Pant on 10/17/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class SearchViewController: UIViewController, UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var searchBar: UISearchBar!
    
    @IBOutlet weak var displayNameLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    
    @IBOutlet weak var friendsButton: UIButton!
    @IBOutlet weak var addFriendButton: UIButton!
    @IBOutlet weak var displayPostTable: UITableView!
    
    private var postDocs: [Post] = []
    private var foundUserID: String?
    var user: User?
    private let db = Firestore.firestore()
    private var isAlreadyFriend = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBar.delegate = self
        displayPostTable.dataSource = self
        displayPostTable.delegate = self
        displayPostTable.isScrollEnabled = true
        displayPostTable.rowHeight = UITableView.automaticDimension
        displayPostTable.estimatedRowHeight = 72
        
        // Hide UI until user found
        [displayNameLabel, nameLabel, displayPostTable].forEach { $0?.isHidden = true }
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
        db.collection("userInfo")
            .whereField("displayName", isEqualTo: displayName)
            .limit(to: 1)
            .getDocuments { [weak self] snap, err in
                guard let self = self else { return }
                if let err = err {
                    self.alert("Error", err.localizedDescription)
                    return
                }
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
                
                DispatchQueue.main.async {
                    self.updateProfileUI()
                    self.fetchPostsForUser()
                }
            }
    }
    
    private func updateProfileUI() {
        guard let u = user else { return }
        
        displayNameLabel.text = "Display Name: \(u.displayName)"
        nameLabel.text        = "Name: \(u.name)"
        friendsButton.setTitle("Friends (\(u.friends.count))", for: .normal)
        
        [displayNameLabel, nameLabel].forEach { $0?.isHidden = false }
        friendsButton.isHidden = false
        addFriendButton.isHidden = false
        displayPostTable.isHidden = false
        
        // Default state
        addFriendButton.isEnabled = false
        addFriendButton.setTitle("Add Friend", for: .normal)
        
        // Disable if it's current user or already a friend
        guard let currentUID = Auth.auth().currentUser?.uid,
              let targetUID = self.foundUserID else { return }
        
        if currentUID == targetUID {
            self.isAlreadyFriend = true
            self.addFriendButton.isEnabled = false
            self.addFriendButton.setTitle("This is You", for: .normal)
            return
        }
        
        db.collection("userInfo").document(currentUID).getDocument { [weak self] doc, _ in
            guard let self = self else { return }
            let mine = doc?.data()?["friends"] as? [String] ?? []
            let already = mine.contains(targetUID)
            DispatchQueue.main.async {
                self.isAlreadyFriend = already
                if already {
                    self.addFriendButton.isEnabled = false
                    self.addFriendButton.setTitle("Already Friends", for: .normal)
                } else {
                    self.addFriendButton.isEnabled = true
                    self.addFriendButton.setTitle("Add Friend", for: .normal)
                }
            }
        }
    }
    
    // MARK: - Fetch Posts
    private func fetchPostsForUser() {
        guard let uid = foundUserID else { return }
        
        self.postDocs.removeAll()
        self.displayPostTable.reloadData()
        
        db.collection("posts").whereField("userID", isEqualTo: uid).getDocuments {
            (querySnapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                for document in querySnapshot!.documents {
                    let data = document.data()
                    if let rating = data["rating"] as? Int ?? (data["rating"] as? NSNumber)?.intValue,
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
                        
                        let newPost = Post(userID: uid,
                                           displayName: self.user?.displayName ?? "Unknown User",
                                           postID: document.documentID,
                                           rating: rating,
                                           likes: likes,
                                           caption: caption,
                                           comments: comments,
                                           trackObject: track)
                        self.postDocs.append(newPost)
                    }
                }
                
                DispatchQueue.main.async {
                    print("✅ Loaded \(self.postDocs.count) posts for \(uid)")
                    self.displayPostTable.reloadData()
                }
            }
        }
    }
    
    // MARK: - TableView Data Source
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return postDocs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = displayPostTable.dequeueReusableCell(withIdentifier: "postCell", for: indexPath) as? PostThumbnailTableViewCell else {
            fatalError("Could not dequeue postCell")
        }
        
        let postData = postDocs[indexPath.row]
        cell.songName.text = postData.trackObject.name
        cell.songRating.text = "\(String(postData.rating))/5"
        
        if let albumArtURL = postData.trackObject.albumArt, let url = URL(string: albumArtURL) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data, let img = UIImage(data: data) else { return }
                DispatchQueue.main.async {
                    if let visibleCell = tableView.cellForRow(at: indexPath) as? PostThumbnailTableViewCell {
                        visibleCell.albumPic.image = img
                    }
                }
            }.resume()
        }
        return cell
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
        
        let myDoc = db.collection("userInfo").document(currentUID)
        let friendDoc = db.collection("userInfo").document(friendUID)
        
        myDoc.getDocument { [weak self] snapshot, err in
            guard let self = self else { return }
            if let err = err { self.alert("Error", err.localizedDescription); return }
            
            let mine = snapshot?.data()?["friends"] as? [String] ?? []
            if mine.contains(friendUID) {
                self.isAlreadyFriend = true
                self.addFriendButton.isEnabled = false
                self.addFriendButton.setTitle("Already Friends", for: .normal)
                self.alert("Already Friends", "You’ve already added this user.")
                return
            }
            
            self.addFriendButton.isEnabled = false
            myDoc.updateData(["friends": FieldValue.arrayUnion([friendUID])]) { [weak self] err in
                guard let self = self else { return }
                if let err = err {
                    self.alert("Error", err.localizedDescription)
                    self.addFriendButton.isEnabled = true
                    return
                }
                
                friendDoc.updateData(["friends": FieldValue.arrayUnion([currentUID])]) { _ in }
                
                self.isAlreadyFriend = true
                self.addFriendButton.setTitle("Already Friends", for: .normal)
                self.addFriendButton.isEnabled = false
                
                if var u = self.user, !u.friends.contains(friendUID) {
                    u.friends.append(friendUID)
                    self.user = u
                    self.friendsButton.setTitle("Friends (\(u.friends.count))", for: .normal)
                }
            }
        }
    }
    
    // MARK: - Friends List
    @IBAction func friendsButtonTapped(_ sender: UIButton) {
        guard let ids = user?.friends, !ids.isEmpty else {
            alert("No friends", "This user has no friends yet.")
            return
        }
        performSegue(withIdentifier: "showFriendsSegue", sender: ids)
    }
    
    // MARK: - Prepare Segues
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "postDetailSegue",
           let postIndex = displayPostTable.indexPathForSelectedRow?.row,
           let destVC = segue.destination as? PostDetailViewController {
            destVC.post = postDocs[postIndex]
        }
        
        if segue.identifier == "showFriendsSegue" {
            let ids = (sender as? [String]) ?? []
            if let dest = segue.destination as? UserFriendsViewController {
                dest.friendIDs = ids
                dest.onSelectFriend = { [weak self] uid in
                    guard let self = self else { return }
                    self.searchBar.text = ""
                    self.loadUser(byUID: uid)
                }
            }
        }
    }
    
    private func loadUser(byUID uid: String) {
        db.collection("userInfo").document(uid).getDocument { [weak self] doc, err in
            guard let self = self else { return }
            if let err = err { self.alert("Error", err.localizedDescription); return }
            guard let doc = doc, let data = doc.data() else {
                self.alert("Not found", "Could not load this user.")
                return
            }
            let friends = data["friends"] as? [String] ?? []
            self.foundUserID = doc.documentID
            self.user = User(
                displayName: data["displayName"] as? String ?? "",
                email:       data["email"] as? String ?? "",
                mobileNumber:data["mobileNumber"] as? String ?? "",
                name:        data["name"] as? String ?? "",
                friends:     friends
            )
            DispatchQueue.main.async {
                self.updateProfileUI()
                self.fetchPostsForUser()
            }
        }
    }
    
    // MARK: - Alert Helper
    private func alert(_ title: String, _ msg: String) {
        let ac = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
}

