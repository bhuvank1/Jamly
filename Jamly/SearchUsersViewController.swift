import UIKit
import FirebaseAuth
import FirebaseFirestore

class SearchViewController: UIViewController, UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate {
   
    @IBOutlet weak var searchBar: UISearchBar!
   
    @IBOutlet weak var displayNameLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var mobileNumberLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
   
    @IBOutlet weak var friendsButton: UIButton!   // “Friends (N)”
    @IBOutlet weak var addFriendButton: UIButton! // “Add Friend”
   
    @IBOutlet weak var displayPostTable: UITableView!
   
    private var postDocs: [Post] = []
    private var foundUserID: String?   // Firestore docID (UID) of the currently shown user
    var user: User?                    // parsed user fields from Firestore
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
       
        // Hide UI until a user is found
        [displayNameLabel, emailLabel, mobileNumberLabel, nameLabel, displayPostTable].forEach { $0?.isHidden = true }
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
                self.fetchPostsForUser()
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
       
        // Default until friendship checked
        addFriendButton.isEnabled = false
        addFriendButton.setTitle("Add Friend", for: .normal)
       
        // Disable if this is me, or if already a friend
        guard let currentUID = Auth.auth().currentUser?.uid,
              let targetUID = self.foundUserID else { return }
       
        if currentUID == targetUID {
            self.isAlreadyFriend = true
            self.addFriendButton.isEnabled = false
            self.addFriendButton.setTitle("This is You", for: .normal)
            return
        }
       
        // Check if targetUID is already in my friends list
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
   
    private func fetchPostsForUser() {
        guard let uid = foundUserID else { return }
       
        db.collection("posts")
            .whereField("userID", isEqualTo: uid)
            .getDocuments { [weak self] (snapshot, err) in
                guard let self = self else { return }
                if let err = err {
                    print("Error getting posts: \(err)")
                    self.postDocs.removeAll()
                    self.displayPostTable.reloadData()
                    return
                }
               
                var newPosts: [Post] = []
                for document in snapshot?.documents ?? [] {
                    let data = document.data()
                   
                    let displayName = self.user?.displayName ?? "Unknown User"  // Ensure the displayName is used in the post
                   
                    let ratingInt: Int? = {
                        if let r = data["rating"] as? Int { return r }
                        if let n = data["rating"] as? NSNumber { return n.intValue }
                        return nil
                    }()
                   
                    guard
                        let rating = ratingInt,
                        let caption = data["caption"] as? String,
                        let trackData = data["trackObject"] as? [String: Any]
                    else {
                        print("⚠️ Skipping post \(document.documentID) due to missing fields")
                        continue
                    }
                   
                    let track = Track(
                        id: trackData["id"] as? String ?? "",
                        name: trackData["name"] as? String ?? "Unknown Song",
                        artists: trackData["artists"] as? String ?? "Unknown Artist",
                        duration_ms: trackData["duration_ms"] as? Int ?? 0,
                        albumArt: trackData["albumArt"] as? String,
                        image: nil
                    )
                   
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
                   
                    let newPost = Post(
                        userID: uid,
                        displayName: displayName,  // Use the correct displayName here
                        postID: document.documentID,
                        rating: rating,
                        likes: likes,
                        caption: caption,
                        comments: comments,
                        trackObject: track
                    )
                    newPosts.append(newPost)
                }
               
                DispatchQueue.main.async {
                    self.postDocs = newPosts
                    self.displayPostTable.reloadData()
                }
            }
    }
   
    // MARK: - TableView Data Source
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return postDocs.count
    }
   
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = displayPostTable.dequeueReusableCell(withIdentifier: "postCell", for: indexPath) as? PostThumbnailTableViewCell else {
            fatalError("Could not dequeue timer cell")
        }
       
        let postData = postDocs[indexPath.row]
        cell.songName.text = postData.trackObject.name
        cell.songRating.text = String(postData.rating)
       
        return cell
    }
   
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        displayPostTable.deselectRow(at: indexPath, animated: true)
        // Perform segue to show post details
        performSegue(withIdentifier: "postDetailSegue", sender: indexPath)
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
               
                // OPTIONAL: mutual add (leave as-is or remove per your product)
                friendDoc.updateData(["friends": FieldValue.arrayUnion([currentUID])]) { _ in }
               
                self.isAlreadyFriend = true
                self.addFriendButton.setTitle("Already Friends", for: .normal)
                self.addFriendButton.isEnabled = false
               
                // Update local count
                if var u = self.user, !u.friends.contains(friendUID) {
                    u.friends.append(friendUID)
                    self.user = u
                    self.friendsButton.setTitle("Friends (\(u.friends.count))", for: .normal)
                }
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

    // MARK: - PostDetail segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "postDetailSegue",
           let indexPath = sender as? IndexPath,
           let destVC = segue.destination as? PostDetailViewController {
            // Pass the selected post to PostDetailViewController
            destVC.post = postDocs[indexPath.row]
        }
       
        if segue.identifier == "showFriendsSegue" {
            let ids = (sender as? [String]) ?? []
            if let dest = segue.destination as? UserFriendsViewController {
                dest.friendIDs = ids
                dest.onSelectFriend = { [weak self] uid in
                    guard let self = self else { return }
                    self.searchBar.text = ""          // Clear search bar when returning
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
                DispatchQueue.main.async { self.updateProfileUI() }
            }
        }
   
    // MARK: - Helpers
    private func alert(_ title: String, _ msg: String) {
        let ac = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
}
