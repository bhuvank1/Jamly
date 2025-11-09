import UIKit
import FirebaseAuth
import FirebaseFirestore

import UIKit
import FirebaseAuth
import FirebaseFirestore

class SearchViewController: UIViewController, UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate {

    // MARK: - Outlets (existing)
    @IBOutlet weak var searchBar: UISearchBar!

    @IBOutlet weak var displayNameLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var mobileNumberLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!

    @IBOutlet weak var friendsButton: UIButton!   // “Friends (N)”
    @IBOutlet weak var addFriendButton: UIButton! // “Add Friend”

    // MARK: - NEW: posts table on this screen
    @IBOutlet weak var postsTableView: UITableView!

    // MARK: - State
    private let db = Firestore.firestore()

    private var foundUserID: String?        // Firestore docID (UID) of the shown/searched user
    var user: User?                         // parsed user fields from Firestore

    private var isAlreadyFriend = false

    // Posts for the shown/searched user
    private var posts: [Post] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBar.delegate = self

        postsTableView.dataSource = self
        postsTableView.delegate = self
        postsTableView.rowHeight = UITableView.automaticDimension
        postsTableView.estimatedRowHeight = 72

        // Hide UI until a user is found
        [displayNameLabel, emailLabel, mobileNumberLabel, nameLabel].forEach { $0?.isHidden = true }
        friendsButton.isHidden = true
        addFriendButton.isHidden = true
        addFriendButton.isEnabled = false

        // Start with an empty table
        posts.removeAll()
        postsTableView.reloadData()
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
                    self.posts.removeAll()
                    self.postsTableView.reloadData()
                    return
                }

                self.applyUserDocument(doc)
            }
    }

    // Used when returning from Friends list or other flows
    private func loadUser(byUID uid: String) {
        db.collection("userInfo").document(uid).getDocument { [weak self] doc, err in
            guard let self = self else { return }
            if let err = err { self.alert("Error", err.localizedDescription); return }
            guard let doc = doc, doc.exists else {
                self.alert("Not found", "Could not load this user.")
                return
            }
            self.applyUserDocument(doc)
        }
    }

    private func applyUserDocument(_ doc: DocumentSnapshot) {
        self.foundUserID = doc.documentID
        let d = doc.data() ?? [:]
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
            self.fetchPostsForCurrentUser()
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

        // Disable if me / already friend
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

    // MARK: - Posts (embedded table)
    private func fetchPostsForCurrentUser() {
        guard let uid = foundUserID else { return }

        db.collection("posts")
            .whereField("userID", isEqualTo: uid)
            .getDocuments { [weak self] (snapshot, err) in
                guard let self = self else { return }
                if let err = err {
                    print("Error getting posts: \(err)")
                    self.posts.removeAll()
                    self.postsTableView.reloadData()
                    return
                }

                var newPosts: [Post] = []
                snapshot?.documents.forEach { document in
                    let data = document.data()
                    if let rating = (data["rating"] as? Int) ?? (data["rating"] as? NSNumber)?.intValue,
                       let caption = data["caption"] as? String,
                       let likes = data["likes"] as? [String],
                       let musicName = data["musicName"] as? String,
                       let commentDicts = data["comments"] as? [[String: Any]],
                       let uid = self.foundUserID {

                        var comments: [Comment] = []
                        for dict in commentDicts {
                            if let userID = dict["userID"] as? String,
                               let commentText = dict["commentText"] as? String {
                                comments.append(Comment(userID: userID, commentText: commentText))
                            }
                        }

                        let post = Post(userID: uid,
                                        postID: document.documentID,
                                        rating: rating,
                                        likes: likes,
                                        caption: caption,
                                        comments: comments,
                                        musicName: musicName)
                        newPosts.append(post)
                    }
                }

                self.posts = newPosts
                self.postsTableView.reloadData()
            }
    }

    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        posts.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Storyboard: prototype cell with Reuse Identifier "postCell" and class PostThumbnailTableViewCell
        let reuseID = "postCell"
        guard let cell = postsTableView.dequeueReusableCell(withIdentifier: reuseID, for: indexPath) as? PostThumbnailTableViewCell
        else {
            // Safe fallback if prototype isn't registered
            let fallback = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            let p = posts[indexPath.row]
            fallback.textLabel?.text = p.musicName
            fallback.detailTextLabel?.text = "Rating: \(p.rating)"
            return fallback
        }

        let p = posts[indexPath.row]
        cell.songName.text = p.musicName
        cell.songRating.text = String(p.rating)
        return cell
    }

    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        postsTableView.deselectRow(at: indexPath, animated: true)
        performSegue(withIdentifier: "postDetailSegue", sender: indexPath)
    }

    // MARK: - Add Friend (race-safe)
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

        // Re-check before writing to avoid duplicates/races
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

                // OPTIONAL: mutual add
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

    // MARK: - Friends List (programmatic push to avoid double-segue bugs)
    @IBAction func friendsButtonTapped(_ sender: UIButton) {
        guard let ids = user?.friends, !ids.isEmpty else {
            alert("No friends", "This user has no friends yet.")
            return
        }
        guard let vc = storyboard?.instantiateViewController(withIdentifier: "FriendsViewControllerID") as? UserFriendsViewController else {
            assertionFailure("FriendsViewControllerID not found")
            return
        }
        vc.friendIDs = ids
        vc.onSelectFriend = { [weak self] uid in
            guard let self = self else { return }
            self.searchBar.text = ""      // clear search on return
            self.loadUser(byUID: uid)     // reload profile + posts for selected friend
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Navigation (post detail)
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "postDetailSegue",
           let indexPath = sender as? IndexPath,
           let dest = segue.destination as? PostDetailViewController {
            dest.post = posts[indexPath.row]
        }
    }

    // MARK: - Helpers
    private func alert(_ title: String, _ msg: String) {
        let ac = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
}
