import UIKit
import FirebaseAuth
import FirebaseFirestore

class ProfileViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var followersCountButton: UIButton!
    @IBOutlet weak var followingCountButton: UIButton!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var displayPostTable: UITableView!
    @IBOutlet weak var userImage: UIImageView!
    @IBOutlet weak var friendsButton: UIButton!

    private var postDocs: [Post] = []
    private var listener: ListenerRegistration?
    private var myFriendIDs: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        displayPostTable.dataSource = self
        displayPostTable.delegate   = self
        displayPostTable.rowHeight  = UITableView.automaticDimension
        displayPostTable.estimatedRowHeight = 72

        // Load all necessary profile data
        loadUserProfile()      // 👈 NEW
        startListeningForPosts()
        loadFriendList()
    }

    deinit { listener?.remove() }

    // MARK: - Load User Profile (NEW)
    private func loadUserProfile() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.collection("userInfo").document(uid).getDocument { [weak self] snap, err in
            guard let self = self else { return }

            if let err = err {
                print("Error loading user profile:", err.localizedDescription)
                return
            }

            guard let data = snap?.data() else {
                print("No user data found.")
                return
            }

            let displayName = data["displayName"] as? String ?? "Unknown User"
            DispatchQueue.main.async {
                self.usernameLabel.text = displayName   // ✅ Set the username label
            }
        }
    }

    // MARK: - Load current user's friends
    private func loadFriendList() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("userInfo").document(uid).getDocument { [weak self] snap, err in
            guard let self = self else { return }
            if let err = err {
                print("Friend fetch error:", err.localizedDescription)
                return
            }
            let data = snap?.data()
            self.myFriendIDs = data?["friends"] as? [String] ?? []
            DispatchQueue.main.async {
                self.friendsButton.setTitle("Friends (\(self.myFriendIDs.count))", for: .normal)
            }
        }
    }

    // MARK: - Friends Button Action
    @IBAction func friendsButtonTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "showFriendsSegue", sender: myFriendIDs)
    }

    // MARK: - Prepare for segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showFriendsSegue",
           let dest = segue.destination as? UserFriendsViewController,
           let ids  = sender as? [String] {
            dest.friendIDs = ids
        }

        if segue.identifier == "postDetailSegue",
           let postIndex = displayPostTable.indexPathForSelectedRow?.row,
           let destVC = segue.destination as? PostDetailViewController {
            destVC.post = postDocs[postIndex]
        }
    }

    // MARK: - Fetch posts for current user
    private func startListeningForPosts() {
        let db = Firestore.firestore()
        guard let user = Auth.auth().currentUser else { return }

        db.collection("posts").whereField("userID", isEqualTo: user.uid).getDocuments { [weak self] snap, err in
            guard let self = self else { return }
            if let err = err {
                print("Error getting posts:", err)
                return
            }
            self.postDocs.removeAll()
            for doc in snap?.documents ?? [] {
                let d = doc.data()
                guard let caption = d["caption"] as? String else { continue }
                let rating = d["rating"] as? Int ?? (d["rating"] as? NSNumber)?.intValue ?? 0
                let likes = d["likes"] as? [String] ?? []
                let commentsArr = (d["comments"] as? [[String:Any]]) ?? []
                let comments = commentsArr.compactMap { c -> Comment? in
                    guard let uid = c["userID"] as? String,
                          let txt = c["commentText"] as? String else { return nil }
                    return Comment(userID: uid, commentText: txt)
                }
                let trackData = d["trackObject"] as? [String:Any]
                let track = Track(
                    id: trackData?["id"] as? String ?? "",
                    name: trackData?["name"] as? String ?? "Unknown Song",
                    artists: trackData?["artists"] as? String ?? "Unknown Artist",
                    duration_ms: trackData?["duration_ms"] as? Int ?? 0,
                    albumArt: trackData?["albumArt"] as? String,
                    image: nil
                )
                let post = Post(
                    userID: user.uid,
                    displayName: user.displayName ?? "Username",
                    postID: doc.documentID,
                    rating: rating,
                    likes: likes,
                    caption: caption,
                    comments: comments,
                    trackObject: track
                )
                self.postDocs.append(post)
            }
            DispatchQueue.main.async { self.displayPostTable.reloadData() }
        }
    }

    // MARK: - Table View
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { postDocs.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = displayPostTable.dequeueReusableCell(withIdentifier: "postCell", for: indexPath) as? PostThumbnailTableViewCell else {
            fatalError("Could not dequeue postCell")
        }
        let post = postDocs[indexPath.row]
        cell.songName.text = post.trackObject.name
        cell.songRating.text = "\(post.rating)/5"
        if let urlStr = post.trackObject.albumArt, let url = URL(string: urlStr) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let img = UIImage(data: data) {
                    DispatchQueue.main.async {
                        if let visible = tableView.cellForRow(at: indexPath) as? PostThumbnailTableViewCell {
                            visible.albumPic.image = img
                        }
                    }
                }
            }.resume()
        }
        return cell
    }

    private func alert(_ title: String, _ msg: String) {
        let ac = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
}

