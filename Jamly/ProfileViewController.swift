//
//  ProfileViewController.swift
//  Jamly
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class ProfileViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: - Outlets
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var displayPostTable: UITableView!
    @IBOutlet weak var friendsButton: UIButton!
    @IBOutlet weak var addFriendsButton: UIButton!

    // MARK: - Properties
    private var postDocs: [Post] = []
    private var listener: ListenerRegistration?
    private var myFriendIDs: [String] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        applyJamThemeStyling()
        if let navBar = navigationController?.navigationBar {
            navBar.barTintColor = UIColor(hex: "#FFEFE5")
        }

        displayPostTable.dataSource = self
        displayPostTable.delegate   = self

        displayPostTable.rowHeight  = UITableView.automaticDimension
        displayPostTable.estimatedRowHeight = 72
        displayPostTable.separatorStyle = .singleLine // Set to singleLine for separators between cells

        displayPostTable.backgroundColor = UIColor(hex: "#FFC1CC")

        let bgView = UIView()
        bgView.backgroundColor = UIColor(hex: "#FFC1CC")
        displayPostTable.backgroundView = bgView

        // Center the usernameLabel programmatically
        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        usernameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        usernameLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 100).isActive = true

        loadUserProfile()
        loadFriendList()
    }


    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startListeningForPosts()
    }

    deinit { listener?.remove() }

    // MARK: - Styling
    private func applyJamThemeStyling() {
        view.backgroundColor = UIColor(hex: "#FFEFE5")

        usernameLabel.textColor = UIColor(hex: "#3D1F28")
        usernameLabel.font = UIFont(name: "Poppins-SemiBold", size: 26)
        usernameLabel.textAlignment = .center // Center the usernameLabel text

        styleButton(friendsButton, title: "Friends", bgColor: "#FFC1CC")
        styleButton(addFriendsButton, title: "Add Friends", bgColor: "#FFC1CC")
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

    // MARK: - Load User Profile
    private func loadUserProfile() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        Firestore.firestore().collection("userInfo").document(uid)
            .getDocument { [weak self] snap, err in
                guard let self = self else { return }

                if let err = err {
                    print("Error loading user profile:", err.localizedDescription)
                    return
                }

                let displayName = snap?.data()?["displayName"] as? String ?? "Unknown User"

                DispatchQueue.main.async {
                    self.usernameLabel.text = displayName
                }
            }
    }

    // MARK: - Load Friends
    private func loadFriendList() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        Firestore.firestore().collection("userInfo").document(uid)
            .getDocument { [weak self] snap, err in
                guard let self = self else { return }

                if let err = err {
                    print("Friend fetch error:", err.localizedDescription)
                    return
                }

                self.myFriendIDs = snap?.data()?["friends"] as? [String] ?? []
            }
    }

    // MARK: - Actions
    @IBAction func addFriendsButtonTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "showAddFriendsSegue", sender: nil)
    }

    // MARK: - Segues
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showFriendsSegue",
           let dest = segue.destination as? UserFriendsViewController,
           let ids  = sender as? [String] {
            dest.friendIDs = ids
        }

        if segue.identifier == "postDetailSegue",
           let postIndex = displayPostTable.indexPathForSelectedRow?.row,
           let dest = segue.destination as? PostDetailViewController {
            dest.post = postDocs[postIndex]
        }

        if segue.identifier == "showAddFriendsSegue",
           let nav = segue.destination as? UINavigationController,
           let _ = nav.topViewController as? SearchViewController {
            print("Navigating to Add Friends screen")
        }
    }

    // MARK: - Fetch Posts
    private func startListeningForPosts() {
        let db = Firestore.firestore()
        guard let user = Auth.auth().currentUser else { return }

        db.collection("posts")
            .whereField("userID", isEqualTo: user.uid)
            .getDocuments { [weak self] snap, err in

                guard let self = self else { return }
                if let err = err { print("Error getting posts:", err); return }

                self.postDocs.removeAll()

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

                DispatchQueue.main.async {
                    self.displayPostTable.reloadData()
                }
            }
    }

    // MARK: - TableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return postDocs.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        guard let cell = displayPostTable.dequeueReusableCell(
            withIdentifier: "postCell",
            for: indexPath
        ) as? PostThumbnailTableViewCell else { fatalError("Could not dequeue postCell") }

        let post = postDocs[indexPath.row]
        cell.songName.text = post.trackObject.name
        cell.songRating.text = "\(post.rating)/5"

        cell.backgroundColor = UIColor(hex: "#FFC1CC")
        cell.contentView.backgroundColor = UIColor(hex: "#FFC1CC")

        cell.layer.cornerRadius = 12
        cell.contentView.layer.cornerRadius = 12
        cell.layer.masksToBounds = false

        cell.layer.shadowColor = UIColor.black.cgColor
        cell.layer.shadowOpacity = 0.10
        cell.layer.shadowOffset = CGSize(width: 0, height: 2)
        cell.layer.shadowRadius = 4

        cell.layer.shadowPath = UIBezierPath(
            roundedRect: cell.bounds,
            cornerRadius: 12
        ).cgPath

        cell.albumPic.layer.cornerRadius = 10
        cell.albumPic.clipsToBounds = true
        cell.albumPic.layer.borderWidth = 2
        cell.albumPic.layer.borderColor = UIColor(hex: "#FFF8F3").cgColor
        cell.albumPic.layer.shadowOpacity = 0.05
        cell.albumPic.layer.shadowOffset = CGSize(width: 0, height: 2)
        cell.albumPic.layer.shadowRadius = 4

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

    // MARK: - Alerts
    private func alert(_ title: String, _ msg: String) {
        let ac = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
}

