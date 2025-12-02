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

    @IBOutlet weak var yourPostsLabel: UILabel!
    @IBOutlet weak var profileStatsButton: UIButton!
    @IBOutlet weak var listenLaterButton: UIButton!
    
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

        displayPostTable.backgroundColor = UIColor(hex: "#FFEFE5")


        // Center the usernameLabel programmatically
        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        usernameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        usernameLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 100).isActive = true

        loadUserProfile()
        
    }


    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startListeningForPosts()
        loadFriendList()
    }

    deinit { listener?.remove() }

    // MARK: - Styling
    private func applyJamThemeStyling() {
        view.backgroundColor = UIColor(hex: "#FFEFE5")

        usernameLabel.textColor = UIColor(hex: "#3D1F28")
        usernameLabel.font = UIFont(name: "Poppins-SemiBold", size: 26)
        usernameLabel.textAlignment = .center // Center the usernameLabel text

        // styleButton(friendsButton, title: "Friends", bgColor: "#FFC1CC")
//        styleButton(addFriendsButton, title: "Add Friends", bgColor: "#FFC1CC")
        
        listenLaterButton.tintColor = UIColor(red: 0.23921568627450981, green: 0.12156862745098039, blue: 0.1568627450980392, alpha: 1.0)
        profileStatsButton.tintColor = UIColor(red: 0.23921568627450981, green: 0.12156862745098039, blue: 0.1568627450980392, alpha: 1.0)
        friendsButton.tintColor = UIColor(red: 0.23921568627450981, green: 0.12156862745098039, blue: 0.1568627450980392, alpha: 1.0)
        
        if let font = UIFont(name: "Poppins-SemiBold", size: 14) {
            listenLaterButton.subtitleLabel?.font = font
            profileStatsButton.subtitleLabel?.font = font
            friendsButton.titleLabel?.font = font
        }
        
        
        if let font = UIFont(name: "Poppins-SemiBold", size: 13) {
            friendsButton.titleLabel?.font = font
        }
        
        yourPostsLabel.textColor = UIColor(red: 0.23921568627450981, green: 0.12156862745098039, blue: 0.1568627450980392, alpha: 1.0)
        if let font = UIFont(name: "Poppins-Bold", size: 18) {
            yourPostsLabel.font = font
        }
        
        friendsButton.layer.borderColor = UIColor(red: 0.23921568627450981, green: 0.12156862745098039, blue: 0.1568627450980392, alpha: 1.0).cgColor
        friendsButton.layer.borderWidth = 1.5
        friendsButton.layer.cornerRadius = 10
        
        listenLaterButton.layer.borderColor = UIColor(red: 0.23921568627450981, green: 0.12156862745098039, blue: 0.1568627450980392, alpha: 1.0).cgColor
        listenLaterButton.layer.borderWidth = 1.5
        listenLaterButton.layer.cornerRadius = 10
        
        profileStatsButton.layer.borderColor = UIColor(red: 0.23921568627450981, green: 0.12156862745098039, blue: 0.1568627450980392, alpha: 1.0).cgColor
        profileStatsButton.layer.borderWidth = 1.5
        profileStatsButton.layer.cornerRadius = 10
    }

    private func styleButton(_ button: UIButton, title: String, bgColor: String) {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = UIColor(hex: bgColor)
        config.baseForegroundColor = UIColor(hex: "#3D1F28")
        config.cornerStyle = .medium
        config.titleAlignment = .center
        button.configuration = config

        if let font = UIFont(name: "Poppins-SemiBold", size: 14) {
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
                
                DispatchQueue.main.async {
                    let count = self.myFriendIDs.count
                    self.friendsButton.setTitle("\(count) friends", for: .normal)
                }
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

//        if segue.identifier == "showAddFriendsSegue",
//           let nav = segue.destination as? UINavigationController,
//           let _ = nav.topViewController as? SearchViewController {
//        }
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

        cell.backgroundColor = UIColor(hex: "#FFEFE5")
        cell.contentView.backgroundColor = UIColor(hex: "#FFEFE5")

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

