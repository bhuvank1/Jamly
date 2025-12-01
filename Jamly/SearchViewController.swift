//
//  SearchViewController.swift
//  Jamly
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class SearchViewController: UIViewController,
                            UISearchBarDelegate,
                            UITableViewDataSource,
                            UITableViewDelegate {

    // MARK: - Outlets
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var displayNameLabel: UILabel!
    @IBOutlet weak var friendsButton: UIButton!
    @IBOutlet weak var addFriendButton: UIButton!
    @IBOutlet weak var displayPostTable: UITableView!
    @IBOutlet weak var noPostsLabel: UILabel!

    // MARK: - Properties
    private var postDocs: [Post] = []
    private var foundUserID: String?
    private var isAlreadyFriend = false
    private var user: User?
    private let db = Firestore.firestore()

    var initialFriendUID: String?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        applyJamThemeStyling()

        searchBar.delegate = self
        displayPostTable.delegate = self
        displayPostTable.dataSource = self
        displayPostTable.rowHeight = UITableView.automaticDimension
        displayPostTable.estimatedRowHeight = 72

        // Start hidden
        displayNameLabel.isHidden = true
        friendsButton.isHidden = true
        addFriendButton.isHidden = true
        displayPostTable.isHidden = true
        noPostsLabel.isHidden = true

        if let tf = searchBar.searchTextField as UITextField? {
            tf.autocapitalizationType = .none
        }

        if let uid = initialFriendUID {
            loadUser(byUID: uid)
        }
    }

    // MARK: - Styling
    private func applyJamThemeStyling() {
        view.backgroundColor = UIColor(hex: "#FFEFE5")

        displayNameLabel.textColor = UIColor(hex: "#3D1F28")
        displayNameLabel.font = UIFont(name: "Poppins-SemiBold", size: 28)

        noPostsLabel.textColor = UIColor(hex: "#3D1F28")
        noPostsLabel.font = UIFont(name: "Poppins-SemiBold", size: 18)

        styleButton(friendsButton, title: "Friends", bgColor: "#FFC1CC")
        applyAddFriendStyle()


        let bg = UIView()
        bg.backgroundColor = UIColor(hex: "#FFC1CC")
        displayPostTable.backgroundColor = UIColor(hex: "#FFEFE5")
        displayPostTable.backgroundView = nil
        displayPostTable.separatorStyle = .none
        searchBar.searchBarStyle = .minimal
        searchBar.barTintColor = UIColor(hex: "#FFEFE5")
        searchBar.backgroundColor = UIColor(hex: "#FFEFE5")


        if let bgView = searchBar.subviews.first?.subviews.first(where: { $0 is UIImageView }) {
            bgView.isHidden = true
        }

    }

    private func styleButton(_ button: UIButton, title: String, bgColor: String) {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = UIColor(hex: bgColor)
        config.baseForegroundColor = UIColor(hex: "#3D1F28")
        config.cornerStyle = .medium
        config.titleAlignment = .center
        button.configuration = config

        if let font = UIFont(name: "Poppins-SemiBold", size: 15) {
            button.titleLabel?.font = font
        }

        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.1
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
    }

    // MARK: - Add Friend Style (Pink)
    private func applyAddFriendStyle() {
        var config = UIButton.Configuration.filled()
        config.title = "Add As Friend"
        config.baseBackgroundColor = UIColor(hex: "#FFC1CC")    // Pink
        config.baseForegroundColor = UIColor(hex: "#3D1F28")    // Dark text
        config.cornerStyle = .medium
        config.titleAlignment = .center
        addFriendButton.configuration = config

        if let font = UIFont(name: "Poppins-SemiBold", size: 15) {
            addFriendButton.titleLabel?.font = font
        }
    }

    // MARK: - Remove Friend Style (Red)
    private func applyRemoveFriendStyle() {
        var config = UIButton.Configuration.filled()
        config.title = "Remove As Friend"
        config.baseBackgroundColor = UIColor(hex: "#FF6B6B")     // Soft red
        config.baseForegroundColor = .white                     // White text
        config.cornerStyle = .medium
        config.titleAlignment = .center
        addFriendButton.configuration = config

        if let font = UIFont(name: "Poppins-SemiBold", size: 15) {
            addFriendButton.titleLabel?.font = font
        }
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
                    self.alert("Not Found", "No user with that display name.")
                    return
                }

                self.foundUserID = doc.documentID
                let d = doc.data()

                self.user = User(
                    displayName: d["displayName"] as? String ?? "",
                    email: d["email"] as? String ?? "",
                    mobileNumber: d["mobileNumber"] as? String ?? "",
                    name: d["name"] as? String ?? "",
                    friends: d["friends"] as? [String] ?? []
                )

                DispatchQueue.main.async {
                    self.updateProfileUI()
                    self.fetchPostsForUser()
                }
            }
    }

    // MARK: - Load by UID
    public func loadUser(byUID uid: String) {
        db.collection("userInfo").document(uid).getDocument { [weak self] doc, err in
            guard let self = self else { return }

            if let err = err {
                self.alert("Error", err.localizedDescription)
                return
            }
            guard let doc = doc, let data = doc.data() else {
                self.alert("Not Found", "Could not load this user.")
                return
            }

            self.foundUserID = doc.documentID
            self.user = User(
                displayName: data["displayName"] as? String ?? "",
                email: data["email"] as? String ?? "",
                mobileNumber: data["mobileNumber"] as? String ?? "",
                name: data["name"] as? String ?? "",
                friends: data["friends"] as? [String] ?? []
            )

            DispatchQueue.main.async {
                self.updateProfileUI()
                self.fetchPostsForUser()
            }
        }
    }

    // MARK: - Update UI
    private func updateProfileUI() {
        guard let u = user else { return }

        displayNameLabel.text = "\(u.displayName)"
        displayNameLabel.isHidden = false
        friendsButton.isHidden = false
        addFriendButton.isHidden = false

        displayPostTable.isHidden = false
        noPostsLabel.isHidden = true

        guard let myID = Auth.auth().currentUser?.uid,
              let targetID = foundUserID else { return }

        db.collection("userInfo").document(myID).getDocument { [weak self] doc, _ in
            guard let self = self else { return }
            let mine = doc?.data()?["friends"] as? [String] ?? []
            self.isAlreadyFriend = mine.contains(targetID)

            DispatchQueue.main.async {
                if myID == targetID {
                    self.addFriendButton.isEnabled = false
                    var config = UIButton.Configuration.filled()
                    config.title = "This is You"
                    config.baseBackgroundColor = UIColor.gray
                    config.baseForegroundColor = .white
                    config.cornerStyle = .medium
                    config.titleAlignment = .center
                    self.addFriendButton.configuration = config
                    if let font = UIFont(name: "Poppins-SemiBold", size: 15) {
                        self.addFriendButton.titleLabel?.font = font
                    }
                } else {
                    // Other user
                    self.addFriendButton.isEnabled = true
                    if self.isAlreadyFriend {
                        self.applyRemoveFriendStyle()
                    } else {
                        self.applyAddFriendStyle()
                    }
                }
            }
        }
    }


    // MARK: - Fetch Posts
    private func fetchPostsForUser() {
        guard let uid = foundUserID else { return }

        postDocs.removeAll()
        displayPostTable.reloadData()

        db.collection("posts")
            .whereField("userID", isEqualTo: uid)
            .getDocuments { [weak self] snap, err in

                guard let self = self else { return }
                if let err = err { print("Error fetching posts:", err); return }

                for doc in snap?.documents ?? [] {
                    let d = doc.data()

                    guard let caption = d["caption"] as? String else { continue }
                    let rating = d["rating"] as? Int ?? 0
                    let likes = d["likes"] as? [String] ?? []

                    let commentsArr = d["comments"] as? [[String:Any]] ?? []
                    let comments = commentsArr.compactMap {
                        Comment(
                            userID: $0["userID"] as? String ?? "",
                            commentText: $0["commentText"] as? String ?? ""
                        )
                    }

                    let t = d["trackObject"] as? [String:Any]
                    let track = Track(
                        id: t?["id"] as? String ?? "",
                        name: t?["name"] as? String ?? "Unknown Song",
                        artists: t?["artists"] as? String ?? "Unknown Artist",
                        duration_ms: t?["duration_ms"] as? Int ?? 0,
                        albumArt: t?["albumArt"] as? String,
                        image: nil
                    )

                    let post = Post(
                        userID: uid,
                        displayName: user?.displayName ?? "Unknown User",
                        postID: doc.documentID,
                        rating: rating,
                        likes: likes,
                        caption: caption,
                        comments: comments,
                        trackObject: track
                    )
                    self.postDocs.append(post)
                }

                DispatchQueue.main.async {
                    self.displayPostTable.reloadData()

                    if self.postDocs.isEmpty {
                        self.noPostsLabel.text = "\(self.user?.displayName ?? "User") has no posts"
                        self.noPostsLabel.isHidden = false
                        self.displayPostTable.isHidden = true
                    } else {
                        self.noPostsLabel.isHidden = true
                        self.displayPostTable.isHidden = false
                    }
                }
            }
    }

    // MARK: - TableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return postDocs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "postCell",
            for: indexPath
        ) as? PostThumbnailTableViewCell else {
            fatalError("Could not dequeue postCell")
        }

        let post = postDocs[indexPath.row]

        // --- TEXT ---
        cell.songName.text = post.trackObject.name
        cell.songName.textColor = UIColor(hex: "#3D1F28")
        cell.songName.font = UIFont(name: "Poppins-SemiBold", size: 16)

        cell.songRating.text = "\(post.rating)/5"
        cell.songRating.textColor = UIColor(hex: "#3D1F28")
        cell.songRating.font = UIFont(name: "Poppins-Regular", size: 14)

        // --- IMAGE ---
        if let urlStr = post.trackObject.albumArt, let url = URL(string: urlStr) {
            cell.albumPic.image = UIImage(named: "albumPlaceholder")
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let img = UIImage(data: data) {
                    DispatchQueue.main.async {
                        if let visible = tableView.cellForRow(at: indexPath) as? PostThumbnailTableViewCell {
                            visible.albumPic.image = img
                        }
                    }
                }
            }.resume()
        } else {
            cell.albumPic.image = UIImage(named: "albumPlaceholder")
        }

        // --- STYLING ---
        // Match table view background
        let bgColor = UIColor(hex: "#FFEFE5")
        cell.backgroundColor = bgColor
        cell.contentView.backgroundColor = bgColor

        // Very subtle border
        cell.contentView.layer.cornerRadius = 10
        cell.contentView.layer.borderWidth = 0.6
        cell.contentView.layer.borderColor = UIColor(hex: "#3D1F28")
            .withAlphaComponent(0.15).cgColor   // SUPER subtle line
        cell.contentView.layer.masksToBounds = true

        // No shadow for ultra-clean look
        cell.layer.shadowOpacity = 0
        cell.layer.shadowRadius = 0

        // Small padding
        cell.contentView.layoutMargins = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)

        return cell
    }



    // MARK: - Add/Remove Friend Toggle
    @IBAction func addFriendButtonTapped(_ sender: UIButton) {
        guard let myID = Auth.auth().currentUser?.uid else {
            alert("Not signed in", "Please sign in first.")
            return
        }
        guard let friendID = foundUserID else { return }

        if myID == friendID { return }

        let myDoc = db.collection("userInfo").document(myID)
        let friendDoc = db.collection("userInfo").document(friendID)

        addFriendButton.isEnabled = false

        if isAlreadyFriend {
            // REMOVE FRIEND
            myDoc.updateData(["friends": FieldValue.arrayRemove([friendID])])
            friendDoc.updateData(["friends": FieldValue.arrayRemove([myID])])

            isAlreadyFriend = false
            applyAddFriendStyle()
            addFriendButton.isEnabled = true

        } else {
            // ADD FRIEND
            myDoc.updateData(["friends": FieldValue.arrayUnion([friendID])])
            friendDoc.updateData(["friends": FieldValue.arrayUnion([myID])])

            isAlreadyFriend = true
            applyRemoveFriendStyle()
            addFriendButton.isEnabled = true
        }
    }

    // MARK: - Friends button
    @IBAction func friendsButtonTapped(_ sender: UIButton) {
        guard let ids = user?.friends, !ids.isEmpty else {
            alert("No Friends", "This user has no friends.")
            return
        }
        performSegue(withIdentifier: "showFriendsSegue", sender: ids)
    }

    // MARK: - Segues
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "postDetailSegue",
           let i = displayPostTable.indexPathForSelectedRow?.row,
           let dest = segue.destination as? PostDetailViewController {
            dest.post = postDocs[i]
        }

        if segue.identifier == "showFriendsSegue",
           let dest = segue.destination as? UserFriendsViewController {
            dest.friendIDs = user?.friends ?? []
        }
    }

    // MARK: - Unwind
    @IBAction func unwindToSearchViewController(_ segue: UIStoryboardSegue) {
        if let src = segue.source as? UserFriendsViewController,
           let uid = src.selectedFriendUID {
            searchBar.text = ""
            loadUser(byUID: uid)
        }
    }

    // MARK: - Alerts
    private func alert(_ title: String, _ msg: String) {
        let ac = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
}

